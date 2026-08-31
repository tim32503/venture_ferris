require "application_system_test_case"

# Verifies the "spot the difference" minigame restored in bear_controller.js
# for question 9 (REFACTOR_PLAN.md's puzzle/bear interactive-kind restoration:
# Question#interactive? — see that method's comment for why questions 1, 2,
# and 9 have no answer text at all). This exercises the real click-through
# path a player takes: find every hotspot, confirm, and land in the boss
# fight exactly like every other question kind does on a correct answer.
class GameBearPageTest < ApplicationSystemTestCase
  def setup
    @team = Team.create!(serial_no: SecureRandom.alphanumeric(16), test_mode: true)
    @question = Question.create!(
      number: 9, kind: :bear, title: "熊讚（示範找不同）",
      content: "示範內容", level: "1", explanation: "示範解說",
      boss: seed_boss_for(9)
    )
  end

  test "finding all 5 hotspots reveals the confirm button, and confirming redirects into the boss fight" do
    visit_bear_question

    # The confirm button stays hidden until every hotspot has been found —
    # unlike the legacy wheel_bear.php, where the check button was always
    # clickable and could fail on an incomplete/duplicated set.
    assert_selector "[data-bear-target='confirmButton']", visible: :hidden

    hotspots = all("[data-bear-target='hotspot']")
    assert_equal Game::QuestionsController::BEAR_HOTSPOTS.size, hotspots.size
    hotspots.each(&:click)

    assert_selector "[data-bear-target='toast']", text: "恭喜！你找到 5 個不一樣的地方了"
    confirm_button = find("[data-bear-target='confirmButton']", visible: :visible)
    confirm_button.click

    assert_current_path game_boss_path(@question.number)
    assert QuestionAttempt.find_by!(team: @team, question: @question).completed?
  end

  # Clicking an already-found hotspot again must not double-count it (the
  # legacy bug this fixes: bear_controller.js's comment has the full story).
  # Re-clicking hotspot 0 four times, then finding the other four for real,
  # should still reach exactly 5 and reveal the confirm button.
  test "re-clicking an already-found hotspot does not affect the found count" do
    visit_bear_question

    hotspots = all("[data-bear-target='hotspot']")
    first = hotspots.first
    4.times { first.click }
    assert_selector "[data-bear-target='toast']", text: "還有 4 個地方喔"

    hotspots[1..].each(&:click)

    assert_selector "[data-bear-target='confirmButton']", visible: :visible
  end

  private

  def visit_bear_question
    visit game_login_path(sno: @team.serial_no, role: "leader")
    fill_in "email", with: "leader@example.com"
    click_on "進入遊戲"
    assert_current_path game_team_path

    QuestionAttempt.create!(team: @team, question: @question, started_at: Time.current)

    visit game_question_path(@question.number)
    assert_selector "[data-controller='bear']"
  end
end
