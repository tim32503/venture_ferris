# Final per-question score breakdown for a team, keyed by a real
# `question_id` foreign key. It used to be a bare `question_number` integer
# "matching the legacy QUEST_SCORE table" — but `question_attempts` in the
# same schema already used a proper FK, so one schema was describing one
# concept two different ways (docs/SCHEMA_REDESIGN.md §2-2).
#
# Values are computed server-side by ScoreCalculator; time_score/hint_score
# are stored as negative numbers, total_score is floored at 0. The row stays a
# materialized snapshot on purpose: the job bonuses depend on the team's
# composition at settlement time, so it cannot be recomputed afterwards.
class ScoreEntry < ApplicationRecord
  belongs_to :team
  belongs_to :question

  validates :question_id, uniqueness: { scope: :team_id }
  validates :total_score, numericality: { greater_than_or_equal_to: 0 }

  # Scores every question `team` has completed and already defeated the
  # boss for, but doesn't have a ScoreEntry yet (REFACTOR_PLAN.md P4:
  # "scores#create：勝利後由伺服器用 ScoreCalculator 算該題成績寫
  # ScoreEntry"). Idempotent — an already-scored question is left
  # untouched — so both `scores#create` (explicit POST) and `scores#show`
  # (self-healing GET, so the results page works even without a separate
  # POST round-trip) can call this safely.
  #
  # A question only becomes eligible once its boss battle exists and is
  # defeated: REFACTOR_PLAN.md P4 req #7 routes a correct answer straight
  # into that question's boss fight, so "solved" and "boss defeated" are
  # meant to happen together for every question in this batch's design.
  def self.record_pending_for!(team)
    scored_question_ids = team.score_entries.pluck(:question_id)

    team.question_attempts.completed.includes(:question).find_each do |attempt|
      question = attempt.question
      next if scored_question_ids.include?(question.id)

      battle = team.boss_battles.find_by(question: question)
      next unless battle&.ended_at.present?

      calculator = ScoreCalculator.new(question: question, attempt: attempt, team: team, boss_defeated: true)
      team.score_entries.create!(question: question, **calculator.to_h)
    end
  end
end
