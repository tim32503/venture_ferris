# Final per-question score breakdown for a team, keyed by question_number
# (not question_id, matching the legacy QUEST_SCORE table). Values are
# computed server-side by ScoreCalculator; time_score/hint_score are stored
# as negative numbers, total_score is floored at 0.
class ScoreEntry < ApplicationRecord
  belongs_to :team

  validates :question_number, presence: true, uniqueness: { scope: :team_id }
  validates :total_score, numericality: { greater_than_or_equal_to: 0 }

  # Scores every question `team` has completed and already defeated the
  # boss for, but doesn't have a ScoreEntry yet (REFACTOR_PLAN.md P4:
  # "scores#create：勝利後由伺服器用 ScoreCalculator 算該題成績寫
  # ScoreEntry"). Idempotent — an already-scored question_number is left
  # untouched — so both `scores#create` (explicit POST) and `scores#show`
  # (self-healing GET, so the results page works even without a separate
  # POST round-trip) can call this safely.
  #
  # A question only becomes eligible once its boss battle exists and is
  # defeated: REFACTOR_PLAN.md P4 req #7 routes a correct answer straight
  # into that question's boss fight, so "solved" and "boss defeated" are
  # meant to happen together for every question in this batch's design.
  def self.record_pending_for!(team)
    scored_numbers = team.score_entries.pluck(:question_number)

    team.question_attempts.completed.includes(:question).find_each do |attempt|
      question = attempt.question
      next if scored_numbers.include?(question.number)

      battle = team.boss_battles.find_by(boss_no: question.number)
      next unless battle&.ended_at.present?

      calculator = ScoreCalculator.new(question: question, attempt: attempt, team: team, boss_defeated: true)
      team.score_entries.create!(question_number: question.number, **calculator.to_h)
    end
  end
end
