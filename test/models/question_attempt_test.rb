require "test_helper"

class QuestionAttemptTest < ActiveSupport::TestCase
  def build_team
    Team.create!(serial_no: SecureRandom.alphanumeric(16), test_mode: false)
  end

  def build_question(number)
    Question.create!(number: number, kind: :quiz, title: "q#{number}", answer_digest: Question.digest_for("a"))
  end

  test "ended_at nil means still in progress (replaces legacy 9999-12-31 sentinel)" do
    attempt = QuestionAttempt.create!(team: build_team, question: build_question(1), started_at: Time.current, ended_at: nil)
    assert_not attempt.completed?
    assert_nil attempt.elapsed_seconds
  end

  test "completed scope only includes attempts with ended_at present" do
    team = build_team
    in_progress = QuestionAttempt.create!(team: team, question: build_question(1), started_at: Time.current, ended_at: nil)
    completed = QuestionAttempt.create!(team: team, question: build_question(2), started_at: 10.minutes.ago, ended_at: Time.current)

    assert_includes QuestionAttempt.completed, completed
    assert_not_includes QuestionAttempt.completed, in_progress
  end

  test "elapsed_seconds is computed from started_at/ended_at" do
    started = Time.zone.parse("2026-01-01 10:00:00")
    ended = started + 90.seconds
    attempt = QuestionAttempt.create!(team: build_team, question: build_question(1), started_at: started, ended_at: ended)

    assert_equal 90, attempt.elapsed_seconds
  end

  test "unique index rejects a second attempt for the same team+question" do
    team = build_team
    question = build_question(1)
    QuestionAttempt.create!(team: team, question: question, started_at: Time.current)

    dup = QuestionAttempt.new(team: team, question: question, started_at: Time.current)
    assert_raises(ActiveRecord::RecordInvalid) { dup.save! }
  end
end
