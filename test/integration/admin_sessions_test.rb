require "test_helper"

class AdminSessionsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = Admin.create!(email: "admin-session-test@example.com", password: "correct-password")
  end

  test "unauthenticated request to admin root redirects to login" do
    get admin_root_path
    assert_redirected_to admin_login_path
  end

  test "unauthenticated request to serial codes index redirects to login" do
    get admin_serial_codes_path
    assert_redirected_to admin_login_path
  end

  test "login with wrong password re-renders the form and does not open a session" do
    post admin_session_path, params: { email: @admin.email, password: "wrong-password" }

    assert_response :unprocessable_entity
    assert_nil session[:admin_id]

    get admin_root_path
    assert_redirected_to admin_login_path
  end

  test "login failure flash does not reveal whether the account exists" do
    post admin_session_path, params: { email: "nobody@example.com", password: "whatever" }
    assert_response :unprocessable_entity
    unknown_email_flash = flash[:alert]

    post admin_session_path, params: { email: @admin.email, password: "wrong-password" }
    assert_response :unprocessable_entity
    wrong_password_flash = flash[:alert]

    assert_equal unknown_email_flash, wrong_password_flash
  end

  test "login with correct credentials opens a session and reaches the dashboard" do
    post admin_session_path, params: { email: @admin.email, password: "correct-password" }
    assert_redirected_to admin_root_path

    get admin_root_path
    assert_response :success
  end

  test "logout clears the session so admin pages redirect to login again" do
    post admin_session_path, params: { email: @admin.email, password: "correct-password" }
    assert_redirected_to admin_root_path

    delete admin_session_path
    assert_redirected_to admin_login_path

    get admin_root_path
    assert_redirected_to admin_login_path
  end
end
