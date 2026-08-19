require "test_helper"

class ScoreEntryTest < ActiveSupport::TestCase
  def build_team
    Team.create!(serial_no: SecureRandom.alphanumeric(16), test_mode: false)
  end

  test "valid with non-negative total_score" do
    entry = ScoreEntry.new(team: build_team, question_number: 1, total_score: 0)
    assert entry.valid?
  end

  test "invalid with a negative total_score" do
    entry = ScoreEntry.new(team: build_team, question_number: 1, total_score: -1)
    assert_not entry.valid?
    assert_includes entry.errors[:total_score], "must be greater than or equal to 0"
  end

  test "unique index rejects a second entry for the same team+question_number" do
    team = build_team
    ScoreEntry.create!(team: team, question_number: 1)

    dup = ScoreEntry.new(team: team, question_number: 1)
    assert_raises(ActiveRecord::RecordInvalid) { dup.save! }
  end
end
