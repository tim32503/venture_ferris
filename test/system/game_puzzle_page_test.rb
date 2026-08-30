require "application_system_test_case"

# Verifies the jigsaw puzzle page boots the native Pointer Events puzzle
# engine in a real browser (REFACTOR_PLAN.md P3 acceptance: "拼圖頁載入且
# plugin 初始化"; docs/UI_MODERNIZATION_PLAN.md decision 2: jQuery
# `jquery.snap-puzzle.min.js` replaced by `puzzle_controller.js`).
# puzzle_controller.js sets `data-puzzle-initialized="true"` on its own
# element once it has built the board/pieces, and it builds one
# `.puzzle-piece` per grid cell — both are what the first test asserts on,
# without needing to actually solve the jigsaw.
class GamePuzzlePageTest < ApplicationSystemTestCase
  def setup
    @team = Team.create!(serial_no: SecureRandom.alphanumeric(16), test_mode: true)
    # No `answer_digest` — puzzle is an `interactive?` kind (Question#interactive?):
    # the fully-placed grid IS the answer, so there is nothing to hash.
    @question = Question.create!(
      number: 1, kind: :puzzle, title: "美福飯店（示範拼圖）",
      content: "示範內容", level: "1", explanation: "示範解說",
      puzzle_rows: 4, puzzle_cols: 4,
      boss: seed_boss_for(1)
    )
  end

  test "puzzle page connects the puzzle Stimulus controller and initializes the board" do
    visit_puzzle_question

    assert_selector "[data-controller='puzzle'][data-puzzle-initialized='true']"
    assert_selector ".puzzle-piece", count: @question.puzzle_rows * @question.puzzle_cols
  end

  # Drags a single piece with a real W3C Actions pointer sequence (down on
  # the piece, move to its correct slot, up) rather than Capybara's
  # `drag_and_drop`/`drag_to`, which drives HTML5 `dragstart`/`dragover`
  # semantics and never dispatches `pointerdown`/`pointermove`/`pointerup` —
  # this controller only listens for Pointer Events, so that helper would
  # silently do nothing. `Selenium::WebDriver::ActionBuilder#pointer_down` /
  # `#pointer_up` moved through the OS-level input stack instead produce
  # trusted pointer events, which is what `setPointerCapture` needs.
  test "dragging a piece onto its own slot snaps and locks it" do
    visit_puzzle_question

    piece = find(".puzzle-piece[data-row='0'][data-col='0']")
    slot = find(".puzzle-slot[data-row='0'][data-col='0']")

    drag_native(piece, slot)

    assert_selector ".puzzle-board .puzzle-piece.is-locked[data-row='0'][data-col='0']"
    piece_after = find(".puzzle-piece[data-row='0'][data-col='0']")
    assert_equal "true", piece_after["data-locked"]
  end

  # Puzzle is an `interactive?` question (Question#interactive?): dragging
  # every piece into place IS the answer, with no text form to fill in —
  # `onPuzzleComplete` in puzzle_controller.js submits the hidden completion
  # form itself once `placedCount` reaches `rows * columns`. This drags all
  # 16 pieces of the 4x4 board (not just one, like the test above) so the
  # completion path actually fires, then asserts the same redirect-into-the-
  # boss-fight behavior every other question kind gets on a correct answer.
  test "completing the puzzle auto-submits and redirects straight into the boss fight" do
    visit_puzzle_question

    (0...@question.puzzle_rows).each do |row|
      (0...@question.puzzle_cols).each do |col|
        piece = find(".puzzle-piece[data-row='#{row}'][data-col='#{col}']")
        slot = find(".puzzle-slot[data-row='#{row}'][data-col='#{col}']")
        drag_native(piece, slot)
      end
    end

    assert_current_path game_boss_path(@question.number)
    assert QuestionAttempt.find_by!(team: @team, question: @question).completed?
  end

  private

  def visit_puzzle_question
    visit game_login_path(sno: @team.serial_no, role: "leader")
    fill_in "email", with: "leader@example.com"
    click_on "進入遊戲"

    # Capybara's `click_on` returns as soon as the click is dispatched, not
    # once the resulting navigation/session cookie has landed — without a
    # synchronizing assertion here, the QuestionAttempt insert + next
    # `visit` below can race the still-in-flight login POST and hit the
    # question page unauthenticated (redirected to `/` instead).
    assert_current_path game_team_path

    QuestionAttempt.create!(team: @team, question: @question, started_at: Time.current)

    visit game_question_path(@question.number)
    assert_selector "[data-controller='puzzle'][data-puzzle-initialized='true']"
  end

  def drag_native(source, target)
    browser = page.driver.browser
    pointer_input = Selenium::WebDriver::Interactions.pointer(:mouse, name: "mouse")

    browser.action(devices: [ pointer_input ])
      .move_to(source.native)
      .pointer_down(:left)
      .pause(device: pointer_input, duration: 0.1)
      .move_to(target.native)
      .pause(device: pointer_input, duration: 0.1)
      .pointer_up(:left)
      .perform
  end
end
