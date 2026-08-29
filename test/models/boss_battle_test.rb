require "test_helper"

class BossBattleTest < ActiveSupport::TestCase
  def build_team
    Team.create!(serial_no: SecureRandom.alphanumeric(16), test_mode: false)
  end

  test "not defeated while attack_count is below hp" do
    battle = BossBattle.create!(team: build_team, boss_no: 1, hp: 10, attack_count: 9)
    assert_not battle.defeated?
  end

  test "defeated once attack_count reaches hp" do
    battle = BossBattle.create!(team: build_team, boss_no: 1, hp: 10, attack_count: 10)
    assert battle.defeated?
  end

  test "hp_percent reflects remaining hit points" do
    battle = BossBattle.create!(team: build_team, boss_no: 1, hp: 10, attack_count: 4)
    assert_equal 60.0, battle.hp_percent
  end

  test "hp_percent never goes below 0 even if attack_count overshoots hp" do
    battle = BossBattle.create!(team: build_team, boss_no: 1, hp: 10, attack_count: 15)
    assert_equal 0.0, battle.hp_percent
  end

  test "unique index rejects a second battle for the same team+boss_no" do
    team = build_team
    BossBattle.create!(team: team, boss_no: 1)

    dup = BossBattle.new(team: team, boss_no: 1)
    assert_raises(ActiveRecord::RecordInvalid) { dup.save! }
  end

  test "critical_ready? is true when no critical has ever been accepted" do
    battle = BossBattle.create!(team: build_team, boss_no: 1, hp: 10)
    assert battle.critical_ready?
  end

  test "critical_ready? is false within the throttle window" do
    battle = BossBattle.create!(team: build_team, boss_no: 1, hp: 10, last_critical_at: Time.current)
    assert_not battle.critical_ready?(Time.current + 1.second)
  end

  test "critical_ready? is true once the throttle window has elapsed" do
    battle = BossBattle.create!(team: build_team, boss_no: 1, hp: 10, last_critical_at: 3.seconds.ago)
    assert battle.critical_ready?
  end

  test "ready_count derives from boss_readies rows, not a raw counter" do
    team = build_team
    battle = BossBattle.create!(team: team, boss_no: 1)
    player = Player.create!(team: team, role: :leader, email: "leader@example.com")

    battle.boss_readies.create!(player: player)
    assert_equal 1, battle.ready_count

    # Idempotency: re-marking the same player ready must not double-count.
    dup = battle.boss_readies.new(player: player)
    assert_raises(ActiveRecord::RecordInvalid) { dup.save! }
    assert_equal 1, battle.ready_count
  end
end
