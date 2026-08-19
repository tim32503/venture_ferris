require "test_helper"

class BossReadyTest < ActiveSupport::TestCase
  def build_team
    Team.create!(serial_no: SecureRandom.alphanumeric(16), test_mode: false)
  end

  test "unique index rejects duplicate [boss_battle, player]" do
    team = build_team
    battle = BossBattle.create!(team: team, boss_no: 1)
    player = Player.create!(team: team, role: :leader, email: "leader@example.com")

    BossReady.create!(boss_battle: battle, player: player)
    dup = BossReady.new(boss_battle: battle, player: player)

    assert_raises(ActiveRecord::RecordInvalid) { dup.save! }
  end

  test "the same player can be ready in two different boss battles" do
    team = build_team
    player = Player.create!(team: team, role: :leader, email: "leader@example.com")
    battle_a = BossBattle.create!(team: team, boss_no: 1)
    battle_b = BossBattle.create!(team: team, boss_no: 2)

    assert BossReady.create!(boss_battle: battle_a, player: player).persisted?
    assert BossReady.create!(boss_battle: battle_b, player: player).persisted?
  end
end
