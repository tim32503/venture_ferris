require "test_helper"

class ScoreEntryTest < ActiveSupport::TestCase
  def build_team
    Team.create!(serial_no: SecureRandom.alphanumeric(16), test_mode: false)
  end

  # docs/SCHEMA_REDESIGN.md §2-2: entries are keyed by a real question row now,
  # so building one is a precondition. Every assertion below is unchanged.
  def build_question(number = 1)
    Question.create!(number: number, kind: :quiz, title: "q#{number}",
                     boss: seed_boss_for(number), answer_digest: Question.digest_for("a#{number}"))
  end

  test "valid with non-negative total_score" do
    entry = ScoreEntry.new(team: build_team, question: build_question, total_score: 0)
    assert entry.valid?
  end

  test "invalid with a negative total_score" do
    entry = ScoreEntry.new(team: build_team, question: build_question, total_score: -1)
    assert_not entry.valid?
    assert_includes entry.errors[:total_score], "must be greater than or equal to 0"
  end

  test "unique index rejects a second entry for the same team+question" do
    team = build_team
    question = build_question
    ScoreEntry.create!(team: team, question: question)

    dup = ScoreEntry.new(team: team, question: question)
    assert_raises(ActiveRecord::RecordInvalid) { dup.save! }
  end
end
