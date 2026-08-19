require "test_helper"

module Game
  # Home / maps / questions (REFACTOR_PLAN.md P3 batch): main menu,
  # map navigation, the three question kinds (puzzle/quiz/bear), and the
  # timer/answer/hints/status member actions. The central acceptance bar
  # from REFACTOR_PLAN.md §0 applies throughout: the server is the only
  # thing that ever checks an answer, and `#show` must never leak one.
  class QuestionFlowTest < ActionDispatch::IntegrationTest
    def create_team(**attrs)
      Team.create!({ serial_no: SecureRandom.alphanumeric(16), test_mode: true }.merge(attrs))
    end

    def sign_in_leader(team)
      post game_session_path, params: { serial_no: team.serial_no, role: "leader", email: "leader@example.com", gender: "male" }
      team.players.find_by!(email: "leader@example.com")
    end

    def seed_question(number, **attrs)
      Question.create!({
        number: number,
        kind: :quiz,
        title: "第 #{number} 題",
        content: "示範內容 #{number}",
        level: "1",
        hint1: "提示一 #{number}",
        hint2: "提示二 #{number}",
        explanation: "示範解說 #{number}",
        answer_digest: Question.digest_for("answer#{number}")
      }.merge(attrs))
    end

    test "every game action redirects an unauthenticated visitor" do
      question = seed_question(3)

      assert_redirect_to_root { get game_root_path }
      assert_redirect_to_root { get game_current_map_path }
      assert_redirect_to_root { get game_map_path(1) }
      assert_redirect_to_root { get game_question_path(question.number) }
      assert_redirect_to_root { post timer_game_question_path(question.number) }
      assert_redirect_to_root { post answer_game_question_path(question.number), params: { answer: "x" } }
      assert_redirect_to_root { post hints_game_question_path(question.number) }
      assert_redirect_to_root { get status_game_question_path(question.number) }
    end

    def assert_redirect_to_root
      yield
      assert_response :redirect
      assert_redirected_to root_path
    end

    test "home renders the team name, job, and solved progress" do
      team = create_team(name: "先鋒隊")
      leader = sign_in_leader(team)
      leader.update!(job: :uncle)
      seed_question(1)

      get game_root_path
      assert_response :success
      assert_match "先鋒隊", response.body
      assert_match "阿北", response.body
    end

    test "map index redirects to map 1 below the solved threshold and map 3 at/above it" do
      team = create_team
      sign_in_leader(team)

      get game_current_map_path
      assert_redirected_to game_map_path(1)

      (1..Team::FINAL_MAP_SOLVED_THRESHOLD).each do |n|
        question = seed_question(n)
        QuestionAttempt.create!(team: team, question: question, started_at: 1.minute.ago, ended_at: Time.current)
      end

      get game_current_map_path
      assert_redirected_to game_map_path(3)
    end

    test "map show renders hotspots linking to questions and to map 2 from map 1" do
      create_team.tap { |team| sign_in_leader(team) }

      get game_map_path(1)
      assert_response :success
      assert_select "map#Map1 area", count: 5
      assert_select "map#Map1 area[href=?]", game_map_path(2)
      assert_select "map#Map1 area[href=?]", game_question_path(1)
    end

    test "quiz question renders the quiz template and never leaks the answer" do
      team = create_team
      sign_in_leader(team)
      question = seed_question(3, answer_digest: Question.digest_for("石牆密語"))

      get game_question_path(3)
      assert_response :success
      assert_select "div.dialog", text: /示範內容 3/
      refute_match "石牆密語", response.body
      refute_match question.answer_digest, response.body
    end

    test "puzzle question renders the puzzle template with rows/cols from the question" do
      team = create_team
      sign_in_leader(team)
      seed_question(1, kind: :puzzle, puzzle_rows: 4, puzzle_cols: 4, answer_digest: Question.digest_for("meifu"))
      post timer_game_question_path(1)

      get game_question_path(1)
      assert_response :success
      assert_select "[data-controller='puzzle'][data-puzzle-rows-value='4'][data-puzzle-columns-value='4']"
      refute_match "meifu", response.body
    end

    test "bear question renders the bear template" do
      team = create_team
      sign_in_leader(team)
      seed_question(9, kind: :bear, answer_digest: Question.digest_for("xiongzan"))
      post timer_game_question_path(9)

      get game_question_path(9)
      assert_response :success
      assert_select "[data-controller='bear']"
      refute_match "xiongzan", response.body
    end

    test "timer is idempotent: a second POST does not reset started_at" do
      team = create_team
      sign_in_leader(team)
      seed_question(4)

      post timer_game_question_path(4)
      first_started_at = QuestionAttempt.find_by!(team: team, question_id: Question.find_by!(number: 4).id).started_at

      travel 5.minutes do
        post timer_game_question_path(4)
      end

      attempt = QuestionAttempt.find_by!(team: team, question_id: Question.find_by!(number: 4).id)
      assert_in_delta first_started_at.to_f, attempt.started_at.to_f, 1.0
    end

    test "wrong answer does not advance and correct answer records ended_at then shows solved" do
      team = create_team
      sign_in_leader(team)
      question = seed_question(5, answer_digest: Question.digest_for("beitou"))
      post timer_game_question_path(5)

      post answer_game_question_path(5), params: { answer: "wrong" }
      assert_redirected_to game_question_path(5)
      attempt = QuestionAttempt.find_by!(team: team, question_id: question.id)
      assert_nil attempt.ended_at

      post answer_game_question_path(5), params: { answer: "  Beitou  " }
      # REFACTOR_PLAN.md P4 req #7: a correct answer now sends the team into
      # that question's boss fight instead of back to the map.
      assert_redirected_to game_boss_path(5)
      assert attempt.reload.completed?

      get game_question_path(5)
      assert_response :success
      assert_match "已經解過", response.body
    end

    test "question 6 rejects hints outright and never shows the hint button" do
      team = create_team
      sign_in_leader(team)
      seed_question(6, hints_enabled: false)
      post timer_game_question_path(6)

      get game_question_path(6)
      assert_select "form[action=?]", hints_game_question_path(6), count: 0

      post hints_game_question_path(6)
      assert_response :forbidden

      attempt = QuestionAttempt.find_by!(team: team, question_id: Question.find_by!(number: 6).id)
      assert_equal 0, attempt.hint_count
    end

    test "hints increment up to the limit and stop granting further ones" do
      team = create_team
      sign_in_leader(team)
      question = seed_question(7)
      post timer_game_question_path(7)

      post hints_game_question_path(7)
      post hints_game_question_path(7)
      attempt = QuestionAttempt.find_by!(team: team, question_id: question.id)
      assert_equal 2, attempt.hint_count

      post hints_game_question_path(7)
      assert_equal 2, attempt.reload.hint_count
    end

    test "question 11 auto-starts its timer just by being shown" do
      team = create_team
      sign_in_leader(team)
      question = seed_question(11, auto_start: true, base_score: 3000)

      get game_question_path(11)
      assert_response :success

      attempt = QuestionAttempt.find_by!(team: team, question_id: question.id)
      assert attempt.started_at.present?
      assert_nil attempt.ended_at
    end

    test "status.json reports started/solved/hint_count and the team-wide active question" do
      team = create_team
      sign_in_leader(team)
      question = seed_question(8)

      get status_game_question_path(8)
      body = JSON.parse(response.body)
      assert_equal({ "started" => false, "solved" => false, "hint_count" => 0, "active_question_number" => nil,
                     "active_boss_number" => nil }, body)

      post timer_game_question_path(8)

      get status_game_question_path(8)
      body = JSON.parse(response.body)
      assert_equal true, body["started"]
      assert_equal 8, body["active_question_number"]

      post answer_game_question_path(8), params: { answer: "answer8" }

      get status_game_question_path(8)
      body = JSON.parse(response.body)
      assert_equal true, body["solved"]
      assert_nil body["active_question_number"]
    end
  end
end
