require "test_helper"

module Game
  # Score + reward + record (REFACTOR_PLAN.md P4): the full chain from a
  # correct answer through a defeated boss to a persisted ScoreEntry and an
  # allocated reward-code pair, plus the negative/floor scoring edge case
  # and reward-allocation guards.
  class SettlementFlowTest < ActionDispatch::IntegrationTest
    def create_team(**attrs)
      Team.create!({ serial_no: SecureRandom.alphanumeric(16), test_mode: true }.merge(attrs))
    end

    def sign_in(team, role:, email:)
      post game_session_path, params: { serial_no: team.serial_no, role: role, email: email, gender: "male" }
      team.players.find_by!(email: email)
    end

    def seed_question(number, **attrs)
      Question.create!({
        number: number, kind: :quiz, title: "第 #{number} 題", content: "內容 #{number}",
        level: "1", explanation: "解說 #{number}", boss_hp: 2, boss_time_limit: 30,
        answer_digest: Question.digest_for("answer#{number}")
      }.merge(attrs))
    end

    def seed_reward_pool(count: 4, test_mode: true)
      count.times { |i| RewardCode.create!(code: "RWD#{SecureRandom.hex(6)}#{i}", test_mode: test_mode) }
    end

    def assert_redirect_to_root
      yield
      assert_response :redirect
      assert_redirected_to root_path
    end

    test "score/reward/record actions redirect an unauthenticated visitor" do
      assert_redirect_to_root { get game_score_path }
      assert_redirect_to_root { post game_score_path }
      assert_redirect_to_root { get game_reward_path }
      assert_redirect_to_root { patch game_reward_contact_path }
      assert_redirect_to_root { post game_reward_codes_path }
      assert_redirect_to_root { get game_record_path }
    end

    test "full chain: answer -> ready -> attack to defeat -> score -> reward" do
      team = create_team
      leader = sign_in(team, role: "leader", email: "leader@example.com")
      seed_question(10, base_score: 1000)
      seed_reward_pool

      post timer_game_question_path(10)
      post answer_game_question_path(10), params: { answer: "answer10" }
      assert_redirected_to game_boss_path(10)

      post ready_game_boss_path(10)
      post attacks_game_boss_path(10)
      post attacks_game_boss_path(10) # hp=2 -> defeated
      assert team.boss_battles.find_by!(boss_no: 10).ended_at.present?

      get game_score_path
      assert_response :success
      entry = team.score_entries.find_by!(question_number: 10)
      assert_equal ScoreCalculator::BOSS_DEFEATED_BONUS, entry.boss_score
      assert_operator entry.time_score, :<=, 0
      assert_operator entry.total_score, :>=, 0
      assert_match entry.total_score.to_s, response.body

      patch game_reward_contact_path, params: { name: "測試玩家", mobile: "0900000000", gender: "male" }
      assert_equal "測試玩家", leader.reload.name
      assert_equal "0900000000", leader.mobile

      post game_reward_codes_path
      first_codes = RewardCode.where(player_email: leader.email).order(:id).pluck(:code)
      assert_equal 2, first_codes.size

      # Idempotent: re-allocating for the same email returns the same pair,
      # never draws more from the pool.
      post game_reward_codes_path
      second_codes = RewardCode.where(player_email: leader.email).order(:id).pluck(:code)
      assert_equal first_codes, second_codes

      get game_reward_path
      assert_response :success
      first_codes.each { |code| assert_match code, response.body }
    end

    test "allocate_codes is refused until contact info is filled in" do
      team = create_team
      leader = sign_in(team, role: "leader", email: "leader@example.com")
      seed_reward_pool

      post game_reward_codes_path
      assert_redirected_to game_reward_path
      assert_equal 0, RewardCode.where(player_email: leader.email).count
    end

    test "score entries store negative time/hint components and total floors at 0" do
      team = create_team
      sign_in(team, role: "leader", email: "leader@example.com")
      seed_question(11, base_score: 10, boss_hp: 1)

      post timer_game_question_path(11)
      post hints_game_question_path(11)
      post hints_game_question_path(11)

      travel 20.minutes do
        post answer_game_question_path(11), params: { answer: "answer11" }
      end
      assert_redirected_to game_boss_path(11)

      post ready_game_boss_path(11)
      post attacks_game_boss_path(11) # hp=1 -> defeated

      post game_score_path
      entry = team.score_entries.find_by!(question_number: 11)

      assert_operator entry.time_score, :<, 0
      assert_operator entry.hint_score, :<, 0
      # 10 (base) - 1200 (time) - 100 (2 hints) + 666 (boss) + 0 (job) < 0
      assert_equal 0, entry.total_score
    end

    test "records lists completed questions with their elapsed time and hint count" do
      team = create_team
      sign_in(team, role: "leader", email: "leader@example.com")
      question = seed_question(9, title: "熊讚題")
      QuestionAttempt.create!(team: team, question: question, started_at: 2.minutes.ago, ended_at: Time.current, hint_count: 1)

      get game_record_path
      assert_response :success
      assert_match "熊讚題", response.body
    end
  end
end
