require "application_system_test_case"

# Verifies the jigsaw puzzle page actually boots the snapPuzzle plugin in a
# real browser (REFACTOR_PLAN.md P3 acceptance: "拼圖頁載入且 plugin 初始化").
# puzzle_controller.js sets `data-puzzle-initialized="true"` on its own
# element once it has called `.snapPuzzle(...)`, and the plugin itself
# builds one `.snappuzzle-piece` per grid cell inside the pile — both are
# what this asserts on, without needing to actually solve the jigsaw.
class GamePuzzlePageTest < ApplicationSystemTestCase
  test "puzzle page connects the puzzle Stimulus controller and initializes snapPuzzle" do
    team = Team.create!(serial_no: SecureRandom.alphanumeric(16), test_mode: true)
    question = Question.create!(
      number: 1, kind: :puzzle, title: "美福飯店（示範拼圖）",
      content: "示範內容", level: "1", explanation: "示範解說",
      puzzle_rows: 4, puzzle_cols: 4,
      answer_digest: Question.digest_for("meifu")
    )

    visit game_login_path(sno: team.serial_no, role: "leader")
    fill_in "email", with: "leader@example.com"
    click_on "進入遊戲"

    # Capybara's `click_on` returns as soon as the click is dispatched, not
    # once the resulting navigation/session cookie has landed — without a
    # synchronizing assertion here, the QuestionAttempt insert + next
    # `visit` below can race the still-in-flight login POST and hit the
    # question page unauthenticated (redirected to `/` instead).
    assert_current_path game_team_path

    QuestionAttempt.create!(team: team, question: question, started_at: Time.current)

    visit game_question_path(question.number)

    assert_selector "[data-controller='puzzle'][data-puzzle-initialized='true']"
    assert_selector ".snappuzzle-piece", count: question.puzzle_rows * question.puzzle_cols
  end
end
