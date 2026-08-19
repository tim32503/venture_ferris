require "application_system_test_case"

# Verifies the team page actually boots its Stimulus polling controller in a
# real browser (REFACTOR_PLAN.md P2 acceptance: "Stimulus 有 connect").
# poll_controller.js sets `data-polling="true"` on its own element inside
# `connect()`, which is what we assert on here.
class GameTeamPageTest < ApplicationSystemTestCase
  test "team page connects the team-poll Stimulus controller" do
    team = Team.create!(serial_no: SecureRandom.alphanumeric(16), test_mode: true)

    visit game_login_path(sno: team.serial_no, role: "leader")
    fill_in "email", with: "leader@example.com"
    click_on "進入遊戲"

    assert_current_path game_team_path
    assert_selector "main[data-controller='team-poll'][data-polling='true']"
  end
end
