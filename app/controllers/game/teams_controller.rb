module Game
  # Team naming + roster (legacy `wheel/team`, `regTeamNM`, `checkTeamNM`,
  # `getTeamNM`, `getTeamUser` — see docs/REFACTOR_PLAN.md §2).
  class TeamsController < BaseController
    # 2-10 chars, Chinese/English/digits only — same shape as the legacy
    # client-side regex in `wheel_team.php:222`, now also enforced server-side.
    TEAM_NAME_FORMAT = /\A[\p{Han}a-zA-Z0-9]{2,10}\z/

    def show
    end

    # PATCH /game/team — only the leader may name the team, and only once
    # (legacy `regTeamNM` was a no-op once `TEAM_NM` was already set).
    def update
      unless current_player.leader?
        return redirect_to game_team_path, alert: "只有隊長可以設定隊名"
      end

      if current_team.name.present?
        return redirect_to game_job_path
      end

      name = params[:name].to_s.strip

      unless valid_team_name?(name)
        return redirect_to game_team_path, alert: "請依照格式輸入團名（2~10字，限中文、英文、數字）"
      end

      if current_team.update(name: name)
        redirect_to game_job_path, notice: "隊名設定成功"
      else
        redirect_to game_team_path, alert: current_team.errors.full_messages.to_sentence
      end
    end

    # GET /game/team/status.json — polled by the team-poll Stimulus
    # controller. No blocking wait loop (legacy `getTeamNM` used
    # `while(true) { ... usleep(1000) }`); this just answers the current
    # state immediately.
    def status
      render json: {
        name: current_team.name,
        ready: current_team.name.present?,
        total: current_team.players.count
      }
    end

    private

    def valid_team_name?(name)
      name.present? && TEAM_NAME_FORMAT.match?(name)
    end
  end
end
