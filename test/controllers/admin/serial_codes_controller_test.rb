require "test_helper"

class Admin::SerialCodesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = Admin.create!(email: "admin-serial-codes-test@example.com", password: "correct-password")
    sign_in_as_admin
  end

  test "redirects to login when not authenticated" do
    delete admin_session_path # log back out
    get admin_serial_codes_path
    assert_redirected_to admin_login_path
  end

  test "index renders a QR code SVG per team" do
    Team.create!(serial_no: "QRTESTTEAM000001")
    get admin_serial_codes_path

    assert_response :success
    assert_match(/<svg[^>]*class="qr-code"/, response.body)
  end

  test "create writes the requested number of unique 16-char serial numbers" do
    assert_difference "Team.count", 5 do
      post admin_serial_codes_path, params: { count: 5, test_mode: "1" }
    end

    assert_redirected_to admin_serial_codes_path

    new_teams = Team.order(created_at: :desc).limit(5)
    serial_nos = new_teams.map(&:serial_no)

    assert_equal 5, serial_nos.uniq.size
    serial_nos.each do |serial_no|
      assert_equal 16, serial_no.length
      assert_match(/\A[A-Z0-9]{16}\z/, serial_no)
    end
    assert new_teams.all?(&:test_mode?)
  end

  test "create defaults to 50 teams when count is not given" do
    assert_difference "Team.count", Admin::SerialCodesController::DEFAULT_COUNT do
      post admin_serial_codes_path
    end
  end

  test "create clamps an excessive count to the maximum" do
    assert_difference "Team.count", Admin::SerialCodesController::MAX_COUNT do
      post admin_serial_codes_path, params: { count: 999_999 }
    end
  end

  private

  def sign_in_as_admin
    post admin_session_path, params: { email: @admin.email, password: "correct-password" }
  end
end
