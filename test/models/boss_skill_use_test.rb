require "test_helper"

class BossSkillUseTest < ActiveSupport::TestCase
  def build_team
    Team.create!(serial_no: SecureRandom.alphanumeric(16), test_mode: false)
  end

  def build_question(number = 1)
    Question.create!(number: number, kind: :quiz, title: "q#{number}",
                     boss: seed_boss_for(number), answer_digest: Question.digest_for("a#{number}"))
  end

  test "unique index rejects a second skill use by the same player in the same battle" do
    team = build_team
    battle = BossBattle.create!(team: team, question: build_question)
    player = Player.create!(team: team, role: :leader, email: "leader@example.com", job: :uncle)

    BossSkillUse.create!(boss_battle: battle, player: player, skill: "uncle", consumed_at: Time.current)
    dup = BossSkillUse.new(boss_battle: battle, player: player, skill: "uncle")

    assert_raises(ActiveRecord::RecordInvalid) { dup.save! }
  end

  test "the same player can use a skill in two different battles" do
    team = build_team
    player = Player.create!(team: team, role: :leader, email: "leader@example.com", job: :uncle)
    battle_a = BossBattle.create!(team: team, question: build_question(1))
    battle_b = BossBattle.create!(team: team, question: build_question(2))

    assert BossSkillUse.create!(boss_battle: battle_a, player: player, skill: "uncle", consumed_at: Time.current).persisted?
    assert BossSkillUse.create!(boss_battle: battle_b, player: player, skill: "uncle", consumed_at: Time.current).persisted?
  end

  test "skill must be one of the four job keys" do
    team = build_team
    battle = BossBattle.create!(team: team, question: build_question)
    player = Player.create!(team: team, role: :leader, email: "leader@example.com")

    use = BossSkillUse.new(boss_battle: battle, player: player, skill: "wizard")
    assert_not use.valid?
    assert_includes use.errors[:skill], "is not included in the list"
  end

  test "pending? is true until consumed_at is set" do
    team = build_team
    battle = BossBattle.create!(team: team, question: build_question)
    player = Player.create!(team: team, role: :leader, email: "leader@example.com", job: :senior)

    use = BossSkillUse.create!(boss_battle: battle, player: player, skill: "senior")
    assert use.pending?

    use.update!(consumed_at: Time.current)
    assert_not use.pending?
  end

  # Regression: Player originally had `has_many :boss_readies, dependent:
  # :destroy` but no equivalent for `boss_skill_uses`, so destroying a player
  # who had activated a Boss skill hit the `boss_skill_uses.player_id`
  # foreign key instead of cascading (found while cleaning up dev-server
  # demo data during manual verification of this feature).
  test "destroying a player cascades to their boss_skill_uses" do
    team = build_team
    battle = BossBattle.create!(team: team, question: build_question)
    player = Player.create!(team: team, role: :leader, email: "leader@example.com", job: :uncle)
    use = BossSkillUse.create!(boss_battle: battle, player: player, skill: "uncle", consumed_at: Time.current)

    player.destroy!

    assert_not BossSkillUse.exists?(use.id)
  end

  # Same regression, exercised the way it actually surfaces in the app: a
  # whole Team destroy cascading through Player.
  test "destroying a team cascades through players to boss_skill_uses" do
    team = build_team
    battle = BossBattle.create!(team: team, question: build_question)
    player = Player.create!(team: team, role: :leader, email: "leader@example.com", job: :uncle)
    use = BossSkillUse.create!(boss_battle: battle, player: player, skill: "uncle", consumed_at: Time.current)

    team.destroy!

    assert_not BossSkillUse.exists?(use.id)
  end
end
