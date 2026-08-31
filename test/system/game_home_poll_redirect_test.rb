require "application_system_test_case"

# Verifies the home page's polling actually redirects in a real browser
# (REFACTOR_PLAN.md §4 requires >= 4 system tests total; this is the 4th,
# covering `active_question_poll_controller.js` — the P3 replacement for the
# legacy `questionIsStart()` client-side poll on `wheel_home.php`). A
# teammate starting a question's timer elsewhere (simulated here directly at
# the model layer, as if from a second browser session) must redirect this
# player's home page to that question within one polling cycle
# (`poll_controller.js`'s `MAX_INTERVAL_MS` = 500ms).
class GameHomePollRedirectTest < ApplicationSystemTestCase
  test "a teammate starting a question elsewhere auto-redirects this player's home page" do
    team = Team.create!(serial_no: SecureRandom.alphanumeric(16), test_mode: true, name: "測試隊")

    # The home page's poll anchors on question #1's status.json endpoint
    # regardless of which question is actually active (see the view's own
    # comment in app/views/game/home/show.html.erb) — Question::FIRST_NUMBER
    # must exist or that endpoint 404s and the poll never gets JSON back.
    Question.create!(
      number: Question::FIRST_NUMBER, kind: :puzzle, title: "錨點題目", content: "示範內容", level: "1",
      explanation: "示範解說", boss_hp: 3, boss_time_limit: 60, puzzle_rows: 1, puzzle_cols: 1,
      answer_digest: Question.digest_for("anchor")
    )

    # number: 3 (not 1) — quiz-kind questions render a "P<number>.png" clue
    # photo (GameHelper#question_image_filename); only puzzle-kind questions
    # 1/2 have a matching "P01.jpg"/"P02.jpg" asset in this repo's asset set.
    question = Question.create!(
      number: 3, kind: :quiz, title: "示範題目", content: "示範內容", level: "1",
      explanation: "示範解說", boss_hp: 3, boss_time_limit: 60,
      answer_digest: Question.digest_for("answer3")
    )

    visit game_login_path(sno: team.serial_no, role: "leader")
    fill_in "email", with: "leader@example.com"
    click_on "進入遊戲"
    assert_current_path game_team_path

    visit game_root_path
    assert_selector "main[data-controller~='active-question-poll']"

    # A teammate elsewhere starts this question's timer (P3's team-wide
    # "someone is timing a question right now" signal — Team#active_question_attempt).
    team.question_attempts.create!(question: question, started_at: Time.current)

    assert_current_path game_question_path(question.number), wait: 5
  end
end
