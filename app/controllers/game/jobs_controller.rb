module Game
  # Job (character class) selection (legacy `wheel/job`, `jobSelect`,
  # `jobCheck`, `jobIsNull` — see docs/REFACTOR_PLAN.md §2/§8-5). The four
  # job effects themselves (uncle/senior/netizen/celebrity) are P4 scope;
  # this controller only handles picking one.
  class JobsController < BaseController
    def show
    end

    # PATCH /game/job — a job may only be picked once per player, and two
    # teammates may not hold the same job (occupancy check; the legacy
    # `jobIsNull` SQL bug that always reported 0 unresolved jobs is not
    # reproduced — see REFACTOR_PLAN.md §8-5).
    def update
      if current_player.job.present?
        return redirect_to game_job_path
      end

      job = params[:job].to_s

      unless Player.jobs.key?(job)
        return redirect_to game_job_path, alert: "請選擇有效的職業"
      end

      if job_taken_by_teammate?(job)
        return redirect_to game_job_path, alert: "這個職業已經被隊友選走了"
      end

      begin
        updated = current_player.update(job: job)
      rescue ActiveRecord::RecordNotUnique
        # 7b (docs/SCHEMA_REDESIGN.md §2-7b): the check above is a
        # read-then-write, so two teammates submitting the same job at the
        # same moment both pass it and the `[team_id, job]` partial unique
        # index decides the winner. The loser lands here and must see exactly
        # what the non-racing loser sees a few lines up.
        return redirect_to game_job_path, alert: "這個職業已經被隊友選走了"
      end

      if updated
        redirect_to game_job_path, notice: "職業選擇成功"
      else
        redirect_to game_job_path, alert: current_player.errors.full_messages.to_sentence
      end
    end

    # GET /game/job/status.json — polled by the job-poll Stimulus
    # controller to disable already-taken jobs. No blocking wait loop
    # (legacy `checkUserJob`/`countUserJobIsNull` used
    # `while(true) { ... usleep(1000) }`).
    def status
      players = current_team.players.select(:email, :job)

      render json: {
        players: players.map { |player| { email: player.email, job: player.job } },
        all_selected: current_team.players.where(job: nil).none?
      }
    end

    private

    def job_taken_by_teammate?(job)
      current_team.players.where(job: job).where.not(id: current_player.id).exists?
    end
  end
end
