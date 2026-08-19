require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = Admin.create!(email: "admin-dashboard-test@example.com", password: "correct-password")
  end

  test "redirects to login when not authenticated" do
    get admin_root_path
    assert_redirected_to admin_login_path
  end

  test "shows team/player/claimed reward code counts when authenticated" do
    sign_in_as_admin

    team = Team.create!(serial_no: "DASHTESTTEAM0001", test_mode: true)
    Player.create!(team: team, role: :leader, email: "leader@example.com")
    reward_code = RewardCode.create!(code: "DASH-CLAIMED-1", test_mode: true,
                                      player_email: "leader@example.com", claimed_at: Time.current)

    get admin_root_path

    assert_response :success
    assert_select "h2", text: Team.count.to_s
    assert_select "h2", text: Player.count.to_s
    assert_select "h2", text: RewardCode.claimed.count.to_s
    assert_operator RewardCode.claimed.count, :>=, 1
    assert_includes RewardCode.claimed, reward_code
  end

  private

  def sign_in_as_admin
    post admin_session_path, params: { email: @admin.email, password: "correct-password" }
  end
end
