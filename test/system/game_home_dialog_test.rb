require "application_system_test_case"

# Verifies the home page's "玩法說明" popup, now a native <dialog> driven by
# dialog_controller.js, actually opens and closes in a real browser
# (U2 batch: replaces Bootstrap 4's jQuery-backed Modal — see
# docs/UI_MODERNIZATION_PLAN.md decision 2's modal row).
class GameHomeDialogTest < ApplicationSystemTestCase
  test "clicking 玩法說明 opens the dialog, and the close button closes it" do
    team = Team.create!(serial_no: SecureRandom.alphanumeric(16), test_mode: true, name: "測試隊")

    visit game_login_path(sno: team.serial_no, role: "leader")
    fill_in "email", with: "leader@example.com"
    click_on "進入遊戲"
    assert_current_path game_team_path

    visit game_root_path
    assert_selector "dialog.native-modal", visible: :all
    assert_no_selector "dialog.native-modal[open]"

    click_on "玩法說明"
    assert_selector "dialog.native-modal[open]"
    save_screenshot(Rails.root.join("tmp", "u2_home_dialog_open.png").to_s)

    within "dialog.native-modal" do
      find("button.close").click
    end

    assert_no_selector "dialog.native-modal[open]"
  end
end
