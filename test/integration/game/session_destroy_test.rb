require "test_helper"

module Game
  # DELETE /game/session (REFACTOR_PLAN.md P4 — the one P2 controller edit
  # this batch is allowed to make: adding SessionsController#destroy).
  class SessionDestroyTest < ActionDispatch::IntegrationTest
    def create_team(**attrs)
      Team.create!({ serial_no: SecureRandom.alphanumeric(16), test_mode: true }.merge(attrs))
    end

    test "destroy clears the player session and redirects to root" do
      team = create_team
      post game_session_path, params: { serial_no: team.serial_no, role: "leader", email: "leader@example.com", gender: "male" }

      get game_root_path
      assert_response :success

      delete game_session_path
      assert_redirected_to root_path

      get game_root_path
      assert_redirected_to root_path
    end

    test "destroy without an active session still redirects to root" do
      delete game_session_path
      assert_redirected_to root_path
    end
  end
end
