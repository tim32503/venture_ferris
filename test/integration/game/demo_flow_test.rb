require "test_helper"

module Game
  # The homepage "Demo" button (`app/views/welcome/index.html.erb`) posts
  # `demo: "1"` to `Game::SessionsController#create` instead of joining the
  # fixed-serial `Team::DEMO_SERIAL_NO` team from db/seeds.rb. This covers
  # the fix for the deadlock where a lone visitor could never satisfy the
  # Boss "ready" gate against a team pre-seeded with 4 players
  # (`ready_count >= current_team.players.count`,
  # Game::BossesController#start_if_all_ready!): every click now creates its
  # own brand-new, single-player team, so `ready 1/1` is immediate.
  class DemoFlowTest < ActionDispatch::IntegrationTest
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

    test "POST /game/session with demo: 1 creates a brand-new single-player team and signs the visitor in as its leader" do
      assert_difference -> { Team.count }, 1 do
        assert_difference -> { Player.count }, 1 do
          post game_session_path, params: { demo: "1" }
        end
      end

      assert_redirected_to game_team_path

      player = Player.order(:id).last
      assert player.leader?
      assert player.team.test_mode?
      assert_equal 1, player.team.players.count
    end

    test "two independent demo clicks (two visitors) each get their own isolated single-player team" do
      post game_session_path, params: { demo: "1" }
      visitor_a = Player.order(:id).last
      team_a = visitor_a.team

      # Simulate a second, unrelated visitor: reset the session the way a
      # fresh browser/cookie jar would (no cookies carried over).
      reset!

      post game_session_path, params: { demo: "1" }
      visitor_b = Player.order(:id).last
      team_b = visitor_b.team

      refute_equal team_a.id, team_b.id
      refute_equal visitor_a.email, visitor_b.email
      assert_equal 1, team_a.reload.players.count
      assert_equal 1, team_b.reload.players.count
    end

    test "full demo chain: demo login -> answer -> ready 1/1 -> attack to defeat -> score -> reward" do
      seed_question(1, base_score: 1000)
      seed_reward_pool

      post game_session_path, params: { demo: "1" }
      assert_redirected_to game_team_path
      demo_player = Player.order(:id).last
      demo_team = demo_player.team

      post timer_game_question_path(1)
      post answer_game_question_path(1), params: { answer: "answer1" }
      assert_redirected_to game_boss_path(1)

      # A single-player demo team is ready 1/1 immediately, with no need to
      # wait on (nonexistent) teammates.
      post ready_game_boss_path(1)
      get status_game_boss_path(1)
      body = JSON.parse(response.body)
      assert_equal 1, body["ready"]
      assert_equal 1, body["total"]
      assert_equal true, body["started"]

      post attacks_game_boss_path(1)
      post attacks_game_boss_path(1) # hp=2 -> defeated

      get status_game_boss_path(1)
      assert_equal true, JSON.parse(response.body)["defeated"]
      assert demo_team.boss_battles.find_by!(boss_no: 1).ended_at.present?

      post game_score_path
      assert_redirected_to game_score_path
      follow_redirect!
      assert_response :success
      assert_equal 1, demo_team.score_entries.count

      patch game_reward_contact_path, params: { name: "Demo 玩家", mobile: "0900000000", gender: "male" }
      post game_reward_codes_path

      codes = RewardCode.where(player_email: demo_player.email).order(:id).pluck(:code)
      assert_equal 2, codes.size

      get game_reward_path
      assert_response :success
      codes.each { |code| assert_match code, response.body }
    end

    test "a demo team starts unnamed so the leader gets the naming form (which is the only path onward to job selection)" do
      post game_session_path, params: { demo: "1" }

      demo_team = Player.order(:id).last.team
      assert demo_team.name.blank?

      get game_team_path
      assert_response :success
      assert_match "取個響亮的團名", response.body
    end

    test "a jobless player on an already-named team still gets a link to job selection" do
      post game_session_path, params: { demo: "1" }
      patch game_team_path, params: { name: "測試冒險團" }

      get game_team_path
      assert_response :success
      assert_match game_job_path, response.body
    end
  end
end
