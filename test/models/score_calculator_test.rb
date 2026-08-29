require "test_helper"

class ScoreCalculatorTest < ActiveSupport::TestCase
  def build_team
    Team.create!(serial_no: SecureRandom.alphanumeric(16), test_mode: false)
  end

  def build_question(base_score: 1000)
    number = rand(1..11)
    Question.create!(number: number, kind: :quiz, title: "q", boss: seed_boss_for(number),
                     answer_digest: Question.digest_for("a"), base_score: base_score)
  end

  def build_attempt(team, question, hint_count: 0, elapsed: 60)
    started = Time.zone.parse("2026-01-01 10:00:00")
    QuestionAttempt.create!(team: team, question: question, started_at: started, ended_at: started + elapsed.seconds, hint_count: hint_count)
  end

  test "baseline: no job effects, no boss defeat" do
    team = build_team
    question = build_question(base_score: 1000)
    attempt = build_attempt(team, question, hint_count: 2, elapsed: 60)

    calculator = ScoreCalculator.new(question: question, attempt: attempt, team: team, boss_defeated: false)

    assert_equal 1000, calculator.question_score
    assert_equal(-60, calculator.time_score)
    assert_equal(-100, calculator.hint_score) # 2 hints * 50
    assert_equal 0, calculator.boss_score
    assert_equal 0, calculator.job_score
    assert_equal 1000 - 60 - 100, calculator.total_score
  end

  test "boss_score is awarded when boss_defeated is true" do
    team = build_team
    question = build_question
    attempt = build_attempt(team, question)

    calculator = ScoreCalculator.new(question: question, attempt: attempt, team: team, boss_defeated: true)

    assert_equal ScoreCalculator::BOSS_DEFEATED_BONUS, calculator.boss_score
  end

  test "senior on the team means hints never cost points" do
    team = build_team
    Player.create!(team: team, role: :leader, email: "senior@example.com", job: :senior)
    question = build_question
    attempt = build_attempt(team, question, hint_count: 5)

    calculator = ScoreCalculator.new(question: question, attempt: attempt, team: team)

    assert_equal 0, calculator.hint_score
  end

  test "celebrity on the team adds a +100 job_score bonus" do
    team = build_team
    Player.create!(team: team, role: :leader, email: "celebrity@example.com", job: :celebrity)
    question = build_question
    attempt = build_attempt(team, question)

    calculator = ScoreCalculator.new(question: question, attempt: attempt, team: team)

    assert_equal ScoreCalculator::CELEBRITY_JOB_BONUS, calculator.job_score
  end

  test "uncle and netizen have no scoring effect (they affect boss mechanics, not points)" do
    team = build_team
    Player.create!(team: team, role: :leader, email: "uncle@example.com", job: :uncle)
    Player.create!(team: team, role: :member, email: "netizen@example.com", job: :netizen)
    question = build_question
    attempt = build_attempt(team, question, hint_count: 1)

    calculator = ScoreCalculator.new(question: question, attempt: attempt, team: team)

    assert_equal(-50, calculator.hint_score)
    assert_equal 0, calculator.job_score
  end

  test "total_score is floored at 0 even when penalties exceed the base score" do
    team = build_team
    question = build_question(base_score: 100)
    attempt = build_attempt(team, question, hint_count: 10, elapsed: 500)

    calculator = ScoreCalculator.new(question: question, attempt: attempt, team: team)

    raw_total = 100 - 500 - 500
    assert_operator raw_total, :<, 0
    assert_equal 0, calculator.total_score
  end
end
