require "test_helper"

module Game
  # Error-code parity with the legacy `checkUserData`/`registerPlayer`
  # (docs/REFACTOR_PLAN.md §1.1 / Wheel_model.php:64-108): 01002 invalid
  # serial/role, 01003 invalid email, 01004 team/role at capacity. Also
  # covers the unauthenticated redirect enforced by Game::BaseController.
  class SessionErrorsTest < ActionDispatch::IntegrationTest
    def create_team(**attrs)
      Team.create!({ serial_no: SecureRandom.alphanumeric(16), test_mode: true }.merge(attrs))
    end

    test "unknown serial number redirects to the 01002 error page" do
      post game_session_path, params: { serial_no: "NOTAREALSERIAL16", role: "leader", email: "a@example.com", gender: "male" }

      assert_redirected_to error_page_path(error_code: "01002")
      follow_redirect!
      assert_match "序號", response.body
    end

    test "serial number that is not exactly 16 chars redirects to the 01002 error page" do
      post game_session_path, params: { serial_no: "TOOSHORT", role: "leader", email: "a@example.com", gender: "male" }

      assert_redirected_to error_page_path(error_code: "01002")
    end

    test "invalid role redirects to the 01002 error page" do
      team = create_team

      post game_session_path, params: { serial_no: team.serial_no, role: "captain", email: "a@example.com", gender: "male" }

      assert_redirected_to error_page_path(error_code: "01002")
    end

    test "malformed email redirects to the 01003 error page" do
      team = create_team

      post game_session_path, params: { serial_no: team.serial_no, role: "leader", email: "not-an-email", gender: "male" }

      assert_redirected_to error_page_path(error_code: "01003")
      follow_redirect!
      assert_match "Email", response.body
    end

    test "a second leader for the same team redirects to the 01004 error page" do
      team = create_team
      team.players.create!(role: :leader, email: "first-leader@example.com")

      post game_session_path, params: { serial_no: team.serial_no, role: "leader", email: "second-leader@example.com", gender: "male" }

      assert_redirected_to error_page_path(error_code: "01004")
      follow_redirect!
      assert_match "已滿", response.body
    end

    test "a fourth member for the same team redirects to the 01004 error page" do
      team = create_team
      3.times { |n| team.players.create!(role: :member, email: "member#{n}@example.com") }

      post game_session_path, params: { serial_no: team.serial_no, role: "member", email: "member-overflow@example.com", gender: "male" }

      assert_redirected_to error_page_path(error_code: "01004")
    end

    test "visiting the team page without a session redirects to root" do
      get game_team_path

      assert_redirected_to root_path
    end

    test "visiting the job page without a session redirects to root" do
      get game_job_path

      assert_redirected_to root_path
    end

    test "patching the team without a session redirects to root" do
      patch game_team_path, params: { name: "偷偷" }

      assert_redirected_to root_path
    end
  end
end
