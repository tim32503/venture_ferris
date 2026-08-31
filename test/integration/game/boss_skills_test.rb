require "test_helper"

module Game
  # Boss-fight active skills (docs/JOB_SKILLS_DESIGN.md): one activation per
  # player per battle, effect entirely decided server-side from
  # `current_player.job`. Covers the four effects, the "once per battle"
  # guard, every rejection path, senior's pending-crit consumption, and
  # celebrity's spotlight throttle bypass (in vs. out of the 5s window).
  class BossSkillsTest < ActionDispatch::IntegrationTest
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
        level: "1", explanation: "解說 #{number}", boss_hp: 100, boss_time_limit: 30,
        boss: seed_boss_for(number),
        answer_digest: Question.digest_for("answer#{number}")
      }.merge(attrs))
    end

    def start_battle(team, number)
      post ready_game_boss_path(number)
      team.boss_battles.find_by!(question: Question.find_by!(number: number))
    end

    test "uncle skill adds 10 seconds to bonus_time_seconds and reports the new time limit" do
      team = create_team
      sign_in(team, role: "leader", email: "leader@example.com", job: :uncle)
      seed_question(1)
      battle = start_battle(team, 1)
      assert battle.started_at.present?

      post skill_game_boss_path(1)
      assert_response :success
      body = JSON.parse(response.body)

      assert_equal true, body["ok"]
      assert_equal "uncle", body["skill"]
      assert_equal 10, body["effect"]["bonus_time_seconds"]
      # 30 (question) + 10 (uncle passive) + 10 (uncle active skill)
      assert_equal 50, body["effect"]["time_limit"]
      assert_equal 10, battle.reload.bonus_time_seconds

      get status_game_boss_path(1)
      assert_equal 10, JSON.parse(response.body)["bonus_time_seconds"]
    end

    test "netizen skill deals 5 immediate damage and can defeat the boss outright" do
      team = create_team
      sign_in(team, role: "leader", email: "leader@example.com", job: :netizen)
      seed_question(2, boss_hp: 5)
      battle = start_battle(team, 2)

      post skill_game_boss_path(2)
      assert_response :success
      body = JSON.parse(response.body)

      assert_equal "netizen", body["skill"]
      assert_equal 5, body["effect"]["damage"]
      assert_equal 5, body["effect"]["attack_count"]
      assert_equal true, body["effect"]["defeated"]
      assert battle.reload.defeated?
      assert battle.ended_at.present?
    end

    test "senior skill arms the next attack as a forced, unthrottled critical" do
      team = create_team
      sign_in(team, role: "leader", email: "leader@example.com", job: :senior)
      seed_question(3)
      battle = start_battle(team, 3)

      post skill_game_boss_path(3)
      assert_response :success
      assert_equal true, JSON.parse(response.body)["effect"]["pending_critical"]

      # The forced crit fires even though this attack doesn't claim
      # `critical: 1` at all — senior's pending skill overrides the client's
      # claim entirely, bypassing the throttle check outright.
      post attacks_game_boss_path(3), params: { critical: "0" }
      assert_equal 2, battle.reload.attack_count # base 1, doubled to 2 by the forced crit
      assert battle.last_critical_at.present?

      # The skill is consumed: the very next attack goes back to normal.
      post attacks_game_boss_path(3)
      assert_equal 3, battle.reload.attack_count
    end

    test "celebrity skill opens a 5s window where critical claims bypass the throttle, then closes" do
      team = create_team
      sign_in(team, role: "leader", email: "leader@example.com", job: :celebrity)
      seed_question(4)
      battle = start_battle(team, 4)

      freeze_time = Time.current
      travel_to freeze_time do
        post skill_game_boss_path(4)
        assert_response :success
        body = JSON.parse(response.body)
        assert_equal 5, body["effect"]["spotlight_seconds"]

        get status_game_boss_path(4)
        assert_equal true, JSON.parse(response.body)["spotlight_active"]

        post attacks_game_boss_path(4), params: { critical: "1" }
        assert_equal 2, battle.reload.attack_count
        assert battle.last_critical_at.present?
      end

      # A fraction of a second later — well inside CRITICAL_THROTTLE_SECONDS
      # — but the spotlight window is still open, so this must NOT be
      # throttled: without the bypass this would land as a normal +1.
      travel_to freeze_time + 0.5.seconds do
        post attacks_game_boss_path(4), params: { critical: "1" }
        assert_equal 4, battle.reload.attack_count
      end

      travel_to freeze_time + BossBattle::SPOTLIGHT_SECONDS + 1.second do
        get status_game_boss_path(4)
        assert_equal false, JSON.parse(response.body)["spotlight_active"]

        # Window closed: normal throttle rules apply again. The previous
        # critical is well outside CRITICAL_THROTTLE_SECONDS by now too, so
        # this one is still honored...
        post attacks_game_boss_path(4), params: { critical: "1" }
        assert_equal 6, battle.reload.attack_count
        newest_critical_at = battle.last_critical_at

        # ...but a second one right after it, with the spotlight gone, is
        # throttled back down to a normal +1.
        post attacks_game_boss_path(4), params: { critical: "1" }
        assert_equal 7, battle.reload.attack_count
        assert_equal newest_critical_at, battle.last_critical_at
      end
    end

    test "activating a skill twice in the same battle is rejected the second time" do
      team = create_team
      sign_in(team, role: "leader", email: "leader@example.com", job: :uncle)
      seed_question(5)
      start_battle(team, 5)

      post skill_game_boss_path(5)
      assert_response :success

      post skill_game_boss_path(5)
      assert_response :unprocessable_entity
      body = JSON.parse(response.body)
      assert_equal false, body["ok"]
      assert_equal "already_used", body["error"]
    end

    test "activating a skill before the fight has started is rejected" do
      team = create_team
      sign_in(team, role: "leader", email: "leader@example.com", job: :uncle)
      seed_question(6)

      post skill_game_boss_path(6)
      assert_response :unprocessable_entity
      assert_equal "battle_not_active", JSON.parse(response.body)["error"]
    end

    test "activating a skill against an already-defeated boss is rejected" do
      team = create_team
      sign_in(team, role: "leader", email: "leader@example.com", job: :netizen)
      seed_question(7, boss_hp: 1)
      battle = start_battle(team, 7)
      post attacks_game_boss_path(7)
      assert battle.reload.defeated?

      post skill_game_boss_path(7)
      assert_response :unprocessable_entity
      assert_equal "battle_not_active", JSON.parse(response.body)["error"]
    end

    test "activating a skill with no job chosen is rejected" do
      team = create_team
      sign_in(team, role: "leader", email: "leader@example.com")
      seed_question(8)
      start_battle(team, 8)

      post skill_game_boss_path(8)
      assert_response :unprocessable_entity
      assert_equal "no_job", JSON.parse(response.body)["error"]
    end

    test "status.json reports skill_available and flips to false once the skill is used" do
      team = create_team
      sign_in(team, role: "leader", email: "leader@example.com", job: :uncle)
      seed_question(9)
      start_battle(team, 9)

      get status_game_boss_path(9)
      assert_equal true, JSON.parse(response.body)["skill_available"]

      post skill_game_boss_path(9)

      get status_game_boss_path(9)
      assert_equal false, JSON.parse(response.body)["skill_available"]
    end

    test "every boss skill action redirects an unauthenticated visitor" do
      question = seed_question(10)

      post skill_game_boss_path(question.number)
      assert_response :redirect
      assert_redirected_to root_path
    end
  end
end
