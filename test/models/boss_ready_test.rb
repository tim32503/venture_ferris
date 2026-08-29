require "test_helper"

class BossReadyTest < ActiveSupport::TestCase
  def build_team
    Team.create!(serial_no: SecureRandom.alphanumeric(16), test_mode: false)
  end

  def build_question(number)
    Question.create!(number: number, kind: :quiz, title: "q#{number}",
                     boss: seed_boss_for(number), answer_digest: Question.digest_for("a#{number}"))
  end

  test "unique index rejects duplicate [boss_battle, player]" do
    team = build_team
    battle = BossBattle.create!(team: team, question: build_question(1))
    player = Player.create!(team: team, role: :leader, email: "leader@example.com")

    BossReady.create!(boss_battle: battle, player: player)
    dup = BossReady.new(boss_battle: battle, player: player)

    assert_raises(ActiveRecord::RecordInvalid) { dup.save! }
  end

  test "the same player can be ready in two different boss battles" do
    team = build_team
    player = Player.create!(team: team, role: :leader, email: "leader@example.com")
    battle_a = BossBattle.create!(team: team, question: build_question(1))
    battle_b = BossBattle.create!(team: team, question: build_question(2))

    assert BossReady.create!(boss_battle: battle_a, player: player).persisted?
    assert BossReady.create!(boss_battle: battle_b, player: player).persisted?
  end
end
