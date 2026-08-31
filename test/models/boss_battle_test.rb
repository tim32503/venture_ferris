require "test_helper"

class BossBattleTest < ActiveSupport::TestCase
  def build_team
    Team.create!(serial_no: SecureRandom.alphanumeric(16), test_mode: false)
  end

  # Before docs/SCHEMA_REDESIGN.md §2-1 these tests wrote `boss_no: 1` against
  # a database with no question 1 in it — the referential hole the FK closes,
  # written down as a test. Building the Question first is the only change
  # here; every assertion below is untouched.
  def build_question(number = 1)
    Question.create!(number: number, kind: :quiz, title: "q#{number}",
                     boss: seed_boss_for(number), answer_digest: Question.digest_for("a#{number}"))
  end

  test "not defeated while attack_count is below hp" do
    battle = BossBattle.create!(team: build_team, question: build_question, hp: 10, attack_count: 9)
    assert_not battle.defeated?
  end

  test "defeated once attack_count reaches hp" do
    battle = BossBattle.create!(team: build_team, question: build_question, hp: 10, attack_count: 10)
    assert battle.defeated?
  end

  test "hp_percent reflects remaining hit points" do
    battle = BossBattle.create!(team: build_team, question: build_question, hp: 10, attack_count: 4)
    assert_equal 60.0, battle.hp_percent
  end

  test "hp_percent never goes below 0 even if attack_count overshoots hp" do
    battle = BossBattle.create!(team: build_team, question: build_question, hp: 10, attack_count: 15)
    assert_equal 0.0, battle.hp_percent
  end

  test "unique index rejects a second battle for the same team+question" do
    team = build_team
    question = build_question
    BossBattle.create!(team: team, question: question)

    dup = BossBattle.new(team: team, question: question)
    assert_raises(ActiveRecord::RecordInvalid) { dup.save! }
  end

  test "the two phases of one boss are two separate battles" do
    team = build_team
    boss = Boss.find_or_create_by!(sprite: "mon11")
    first_phase = Question.create!(number: 10, kind: :quiz, title: "F1", boss: boss, boss_phase: 1,
                                   answer_digest: Question.digest_for("a10"))
    final_phase = Question.create!(number: 11, kind: :quiz, title: "F2", boss: boss, boss_phase: 2,
                                   answer_digest: Question.digest_for("a11"))

    assert BossBattle.create!(team: team, question: first_phase).persisted?
    assert BossBattle.create!(team: team, question: final_phase).persisted?
  end

  test "critical_ready? is true when no critical has ever been accepted" do
    battle = BossBattle.create!(team: build_team, question: build_question, hp: 10)
    assert battle.critical_ready?
  end

  test "critical_ready? is false within the throttle window" do
    battle = BossBattle.create!(team: build_team, question: build_question, hp: 10, last_critical_at: Time.current)
    assert_not battle.critical_ready?(Time.current + 1.second)
  end

  test "critical_ready? is true once the throttle window has elapsed" do
    battle = BossBattle.create!(team: build_team, question: build_question, hp: 10, last_critical_at: 3.seconds.ago)
    assert battle.critical_ready?
  end

  test "ready_count derives from boss_readies rows, not a raw counter" do
    team = build_team
    battle = BossBattle.create!(team: team, question: build_question)
    player = Player.create!(team: team, role: :leader, email: "leader@example.com")

    battle.boss_readies.create!(player: player)
    assert_equal 1, battle.ready_count

    # Idempotency: re-marking the same player ready must not double-count.
    dup = battle.boss_readies.new(player: player)
    assert_raises(ActiveRecord::RecordInvalid) { dup.save! }
    assert_equal 1, battle.ready_count
  end
end
