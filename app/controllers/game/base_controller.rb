module Game
  # Shared guard for every player-facing game controller (REFACTOR_PLAN.md
  # §2): all actions require an active player session. `session[:player_id]`
  # is the only authoritative identity — the current team, role, etc. are
  # always derived by looking the Player record back up, never cached
  # separately in the session.
  class BaseController < ApplicationController
    before_action :require_player_session

    private

    def require_player_session
      redirect_to root_path, alert: "請先登入遊戲" unless current_player
    end

    def current_player
      @current_player ||= Player.find_by(id: session[:player_id])
    end
    helper_method :current_player

    def current_team
      @current_team ||= current_player&.team
    end
    helper_method :current_team
  end
end
