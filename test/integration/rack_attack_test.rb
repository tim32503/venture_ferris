require "test_helper"

# Exercises the throttles in config/initializers/rack_attack.rb. The test
# environment's default cache store is `:null_store`
# (config/environments/test.rb), under which Rack::Attack's counters never
# actually persist between requests — so every test here swaps in a real
# in-memory store for the duration of the test, and restores the original
# store afterward so no throttling state leaks into other integration
# tests that also happen to hit these same paths repeatedly (e.g.
# Admin::TeamsControllerTest signing in as admin many times over).
class RackAttackTest < ActionDispatch::IntegrationTest
  def seed_question(number, **attrs)
    Question.create!({
      number: number, kind: :quiz, title: "第 #{number} 題", content: "內容 #{number}",
      level: "1", explanation: "解說 #{number}", boss_hp: 10_000, boss_time_limit: 300,
      boss: seed_boss_for(number),
      answer_digest: Question.digest_for("answer#{number}")
    }.merge(attrs))
  end

  setup do
    @original_cache_store = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.enabled = true
  end

  teardown do
    Rack::Attack.cache.store = @original_cache_store
  end

  test "demo team creation is throttled per IP" do
    limit = Integer(ENV.fetch("RACK_ATTACK_DEMO_LIMIT", 5))

    limit.times do
      post game_session_path, params: { demo: "1" }
      assert_response :redirect
    end

    post game_session_path, params: { demo: "1" }
    assert_response :too_many_requests
    assert_match "請求過於頻繁", response.body
  end

  test "admin login is throttled per IP" do
    limit = Integer(ENV.fetch("RACK_ATTACK_ADMIN_LOGIN_LIMIT", 10))

    limit.times do
      post admin_session_path, params: { email: "nobody@example.com", password: "wrong-password" }
      assert_response :unprocessable_entity
    end

    post admin_session_path, params: { email: "nobody@example.com", password: "wrong-password" }
    assert_response :too_many_requests
    assert_match "請求過於頻繁", response.body
  end

  test "player (non-demo) login is throttled per IP" do
    limit = Integer(ENV.fetch("RACK_ATTACK_PLAYER_LOGIN_LIMIT", 20))

    (limit + 1).times do |i|
      post game_session_path, params: {
        serial_no: "NOSUCHSERIALNO0#{i % 10}", role: "leader", email: "x@example.com", gender: "male"
      }
      if i < limit
        assert_response :redirect
      else
        assert_response :too_many_requests
      end
    end
  end

  test "boss attacks are never throttled, even under a rapid burst" do
    question = seed_question(1)

    post game_session_path, params: { demo: "1" }
    assert_redirected_to game_team_path

    post timer_game_question_path(1)
    post answer_game_question_path(1), params: { answer: "answer1" }
    post ready_game_boss_path(question.number)

    30.times do
      post attacks_game_boss_path(question.number)
      assert_response :redirect, "boss attack ##{_1} was throttled — this must never happen"
    end
  end
end
