require "test_helper"

class TeamTest < ActiveSupport::TestCase
  def build_team(**attrs)
    Team.new({ serial_no: SecureRandom.alphanumeric(16), test_mode: false }.merge(attrs))
  end

  def create_question(number, **attrs)
    Question.create!({
      number: number,
      kind: :quiz,
      title: "q#{number}",
      answer_digest: Question.digest_for("a#{number}")
    }.merge(attrs))
  end

  test "valid with a 16-char serial_no" do
    team = build_team
    assert team.valid?
  end

  test "invalid without serial_no" do
    team = build_team(serial_no: nil)
    assert_not team.valid?
    assert_includes team.errors[:serial_no], "can't be blank"
  end

  test "invalid when serial_no is not exactly 16 chars" do
    team = build_team(serial_no: "TOOSHORT")
    assert_not team.valid?
    assert_includes team.errors[:serial_no], "is the wrong length (should be 16 characters)"
  end

  test "invalid with duplicate serial_no" do
    serial_no = SecureRandom.alphanumeric(16)
    build_team(serial_no: serial_no).save!

    dup = build_team(serial_no: serial_no)
    assert_not dup.valid?
    assert_includes dup.errors[:serial_no], "has already been taken"
  end

  test "solved_count only counts completed question attempts" do
    team = build_team.tap(&:save!)
    q1 = create_question(1)
    q2 = create_question(2)

    team.question_attempts.create!(question: q1, started_at: 1.hour.ago, ended_at: Time.current)
    team.question_attempts.create!(question: q2, started_at: 1.hour.ago, ended_at: nil)

    assert_equal 1, team.solved_count
  end

  test "current_map is 1 below the final-map threshold and 3 at/above it" do
    team = build_team.tap(&:save!)

    (1..8).each do |n|
      question = create_question(n)
      team.question_attempts.create!(question: question, started_at: 1.hour.ago, ended_at: Time.current)
    end
    assert_equal 8, team.solved_count
    assert_equal Team::FIRST_MAP_NUMBER, team.current_map

    ninth = create_question(9)
    team.question_attempts.create!(question: ninth, started_at: 1.hour.ago, ended_at: Time.current)

    assert_equal 9, team.solved_count
    assert_equal Team::FINAL_MAP_NUMBER, team.current_map
  end
end
