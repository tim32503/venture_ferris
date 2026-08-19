module Game
  # Main menu (legacy `wheel/home` — see docs/REFACTOR_PLAN.md §2/P3). Shows
  # the team name, the signed-in player's role/job, and overall progress;
  # polls for a teammate-started question via `active-question-poll` (see
  # active_question_poll_controller.js), replacing the legacy client-side
  # `questionIsStart()`/`BossIsStart()` loops in `wheel_home.php`.
  #
  # Boss polling (`BossIsStart()` in the legacy view) is P4 scope — left as
  # an extension point on the Stimulus controller, not implemented here.
  class HomeController < BaseController
    def show
      @solved_count = current_team.solved_count
      @total_questions = Question::LAST_NUMBER
    end
  end
end
