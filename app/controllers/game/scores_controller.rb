module Game
  # Per-question score breakdown + running total (legacy `wheel/score`,
  # `setScore` — REFACTOR_PLAN.md §2/P4). Scoring a question requires both
  # a completed QuestionAttempt and a defeated BossBattle for that same
  # number (REFACTOR_PLAN.md P4 req #7 routes a correct answer straight
  # into that question's boss fight before settlement); the actual
  # computation lives in `ScoreEntry.record_pending_for!` /
  # `ScoreCalculator` so both `#show` and `#create` share it.
  class ScoresController < BaseController
    def show
      ScoreEntry.record_pending_for!(current_team)
      # Ordered by the question's business number (not by `question_id`) so
      # the table keeps reading 1, 2, 3… exactly as it did when the column
      # was a bare `question_number`.
      @entries = current_team.score_entries.includes(:question).joins(:question).order("questions.number")
      @total = @entries.sum(&:total_score)
    end

    # POST /game/score — legacy `setScore`. Idempotent: already-scored
    # question numbers are left untouched; only newly-eligible ones
    # (solved + boss defeated, not yet scored) get a ScoreEntry written.
    def create
      ScoreEntry.record_pending_for!(current_team)
      redirect_to game_score_path
    end
  end
end
