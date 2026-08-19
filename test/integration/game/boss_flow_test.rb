require "test_helper"

module Game
  # Boss battle mechanics (REFACTOR_PLAN.md P4): ready-up lobby, netizen/
  # other attack deltas, rejecting attacks before the fight starts, and the
  # P4 req #7 hookup that sends a correct answer into the boss page.
  class BossFlowTest < ActionDispatch::IntegrationTest
    def create_team(**attrs)
      Team.create!({ serial_no: SecureRandom.alphanumeric(16), test_mode: true }.merge(attrs))
    end

    def sign_in(team, role:, email:, job: nil)
      post game_session_path, params: { serial_no: team.serial_no, role: role, email: email, gender: "male" }
      player = team.players.find_by!(email: email)
      player.update!(job: job) if job
      player
    end

    def seed_question(number, **attrs)
      Question.create!({
        number: number, kind: :quiz, title: "第 #{number} 題", content: "內容 #{number}",
        level: "1", explanation: "解說 #{number}", boss_hp: 4, boss_time_limit: 30,
        answer_digest: Question.digest_for("answer#{number}")
      }.merge(attrs))
    end

    def assert_redirect_to_root
      yield
      assert_response :redirect
      assert_redirected_to root_path
    end

    test "every boss action redirects an unauthenticated visitor" do
      question = seed_question(1)

      assert_redirect_to_root { get game_boss_path(question.number) }
      assert_redirect_to_root { post ready_game_boss_path(question.number) }
      assert_redirect_to_root { post attacks_game_boss_path(question.number) }
      assert_redirect_to_root { get status_game_boss_path(question.number) }
    end

    test "answering correctly sends the team to that question's boss page" do
      team = create_team
      sign_in(team, role: "leader", email: "leader@example.com")
      seed_question(2)
      post timer_game_question_path(2)

      post answer_game_question_path(2), params: { answer: "answer2" }
      assert_redirected_to game_boss_path(2)
    end

    test "ready is idempotent and the fight only starts once every player has readied up" do
      team = create_team
      sign_in(team, role: "leader", email: "leader@example.com")
      sign_in(team, role: "member", email: "member@example.com")
      seed_question(3)

      post game_session_path, params: { serial_no: team.serial_no, role: "leader", email: "leader@example.com", gender: "male" }
      post ready_game_boss_path(3)
      post ready_game_boss_path(3) # duplicate click from the same player - must not double count

      get status_game_boss_path(3)
      body = JSON.parse(response.body)
      assert_equal 1, body["ready"]
      assert_equal 2, body["total"]
      assert_equal false, body["started"]

      post game_session_path, params: { serial_no: team.serial_no, role: "member", email: "member@example.com", gender: "male" }
      post ready_game_boss_path(3)

      get status_game_boss_path(3)
      assert_equal true, JSON.parse(response.body)["started"]
    end

    test "netizen attacks for +2, everyone else for +1, and defeating writes ended_at" do
      team = create_team
      sign_in(team, role: "leader", email: "leader@example.com")
      seed_question(4, boss_hp: 5)
      post ready_game_boss_path(4)

      sign_in(team, role: "member", email: "netizen@example.com", job: :netizen)
      post ready_game_boss_path(4) # last player readies -> fight starts

      battle = team.boss_battles.find_by!(boss_no: 4)
      assert battle.started_at.present?

      post attacks_game_boss_path(4) # current session: netizen -> +2
      assert_equal 2, battle.reload.attack_count

      post game_session_path, params: { serial_no: team.serial_no, role: "leader", email: "leader@example.com", gender: "male" }
      post attacks_game_boss_path(4) # leader (no job) -> +1
      assert_equal 3, battle.reload.attack_count

      post game_session_path, params: { serial_no: team.serial_no, role: "member", email: "netizen@example.com", gender: "male" }
      post attacks_game_boss_path(4) # 3 + 2 = 5 = hp -> defeated
      battle.reload
      assert battle.defeated?
      assert battle.ended_at.present?
    end

    test "attacking before the fight has started is rejected" do
      team = create_team
      sign_in(team, role: "leader", email: "leader@example.com")
      seed_question(5)

      post attacks_game_boss_path(5)
      assert_redirected_to game_boss_path(5)
      assert_equal 0, team.boss_battles.find_by!(boss_no: 5).attack_count
    end

    test "attacking an already-defeated boss is rejected and does not add more attacks" do
      team = create_team
      sign_in(team, role: "leader", email: "leader@example.com")
      seed_question(6, boss_hp: 1)
      post ready_game_boss_path(6)
      post attacks_game_boss_path(6) # 1 attack defeats hp=1

      battle = team.boss_battles.find_by!(boss_no: 6)
      assert battle.ended_at.present?

      post attacks_game_boss_path(6)
      assert_equal 1, battle.reload.attack_count
    end
  end
end
