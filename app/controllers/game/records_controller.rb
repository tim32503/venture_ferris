module Game
  # Solved-question log (legacy `wheel/record`, `getQuestionSolved` —
  # REFACTOR_PLAN.md §2/P4).
  class RecordsController < BaseController
    def show
      @attempts = current_team.question_attempts.completed.includes(:question).order("questions.number")
    end
  end
end
