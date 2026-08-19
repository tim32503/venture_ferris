# Computes the server-side score breakdown for one team's completed
# question. This intentionally reimplements the *intended* design from
# REFACTOR_PLAN.md §1.2 rather than porting the legacy bugs (uncle/netizen/
# senior/celebrity effects were all broken client-side in the original site):
#
#   - senior on the team: hints never cost points (hint_score stays 0)
#   - celebrity on the team: +100 job_score bonus
#   - time_score / hint_score are stored as negative numbers
#   - total_score is computed server-side and floored at 0
#
# uncle (boss time limit) and netizen (extra attack per click) are boss-battle
# mechanics, not scoring effects, and are applied where boss battles are
# started/attacked rather than here.
class ScoreCalculator
  HINT_PENALTY_PER_HINT = 50
  BOSS_DEFEATED_BONUS = 666
  CELEBRITY_JOB_BONUS = 100

  attr_reader :question, :attempt, :team, :boss_defeated

  def initialize(question:, attempt:, team:, boss_defeated: false)
    @question = question
    @attempt = attempt
    @team = team
    @boss_defeated = boss_defeated
  end

  def question_score
    question.base_score
  end

  def time_score
    -elapsed_seconds
  end

  def hint_score
    return 0 if senior_on_team?

    -(attempt.hint_count.to_i * HINT_PENALTY_PER_HINT)
  end

  def boss_score
    boss_defeated ? BOSS_DEFEATED_BONUS : 0
  end

  def job_score
    celebrity_on_team? ? CELEBRITY_JOB_BONUS : 0
  end

  def total_score
    raw = question_score + time_score + hint_score + boss_score + job_score
    raw.negative? ? 0 : raw
  end

  def to_h
    {
      question_score: question_score,
      time_score: time_score,
      hint_score: hint_score,
      boss_score: boss_score,
      job_score: job_score,
      total_score: total_score
    }
  end

  private

  def elapsed_seconds
    return 0 unless attempt&.started_at && attempt&.ended_at

    (attempt.ended_at - attempt.started_at).round
  end

  def senior_on_team?
    team.players.senior.any?
  end

  def celebrity_on_team?
    team.players.celebrity.any?
  end
end
