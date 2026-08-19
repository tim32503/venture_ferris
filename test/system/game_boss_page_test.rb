require "application_system_test_case"

# Verifies clicking the attack button on the boss page actually updates the
# DOM (REFACTOR_PLAN.md P4 acceptance: "boss 頁點擊攻擊 DOM 更新") — attacks
# are a plain `button_to` POST that Turbo intercepts and re-renders, so this
# also exercises that the redirected-back show page reflects the new
# attack_count each time.
class GameBossPageTest < ApplicationSystemTestCase
  test "clicking attack updates the attack count shown on the page" do
    team = Team.create!(serial_no: SecureRandom.alphanumeric(16), test_mode: true)
    question = Question.create!(
      number: 1, kind: :quiz, title: "示範魔王戰", content: "示範內容", level: "1",
      explanation: "示範解說", boss_hp: 3, boss_time_limit: 60,
      answer_digest: Question.digest_for("answer1")
    )

    visit game_login_path(sno: team.serial_no, role: "leader")
    fill_in "email", with: "leader@example.com"
    click_on "進入遊戲"
    assert_current_path game_team_path

    visit game_boss_path(question.number)
    click_on "宣戰！準備攻擊"

    # Solo team of 1: readying alone already meets "everyone ready", so the
    # fight starts immediately and this is now the battle screen.
    assert_selector "[data-boss-poll-target='attackCount']", text: "0"

    click_on "攻擊！"
    assert_selector "[data-boss-poll-target='attackCount']", text: "1"

    click_on "攻擊！"
    assert_selector "[data-boss-poll-target='attackCount']", text: "2"
  end
end
