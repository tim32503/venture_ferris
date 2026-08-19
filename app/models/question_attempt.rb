# Tracks one team's timing/hints for one question. `ended_at` is NULL while
# the attempt is in progress — this replaces the legacy sentinel timestamp
# `9999-12-31` used by QUEST_LOG.TIME_END.
class QuestionAttempt < ApplicationRecord
  belongs_to :team
  belongs_to :question

  validates :question_id, uniqueness: { scope: :team_id }
  validates :hint_count, numericality: { greater_than_or_equal_to: 0 }

  scope :completed, -> { where.not(ended_at: nil) }
  scope :in_progress, -> { where(ended_at: nil) }

  def completed?
    ended_at.present?
  end

  def elapsed_seconds
    return nil unless started_at && ended_at

    (ended_at - started_at).round
  end
end
