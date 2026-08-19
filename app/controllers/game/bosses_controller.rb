module Game
  # One boss fight per question (legacy `wheel/boss/{bno}`, `attack`,
  # `getBossHP`, `bossIsStart`, `teamIsReady`, `ready` — REFACTOR_PLAN.md
  # §2/P4; see model comments on BossBattle/BossReady for the persistence
  # design). `#show` renders either the ready-up lobby or the battle screen
  # depending on `@battle.started_at`; `#ready`/`#attacks` are classic
  # redirect-driven mutations (same style as Game::TeamsController /
  # Game::JobsController's `#update`, not JSON); `#status` is the only JSON
  # endpoint, polled from the boss page itself.
  #
  # Time limit: `question.boss_time_limit` seconds, +10s if the team has an
  # uncle (REFACTOR_PLAN.md §1.2 — the legacy uncle/netizen/senior/celebrity
  # effects were all broken client-side; this ports the *intended* design,
  # not the bugs). Always computed server-side, never trusted from a client
  # value.
  #
  # Retry-on-timeout: this batch's sandbox could not read the legacy
  # `Wheel_model.php` boss methods directly (the source tree outside this
  # repo was not accessible from here), so the exact legacy UI for an
  # undefeated, timed-out fight could not be inspected first-hand. Per
  # REFACTOR_PLAN.md's own instruction ("時限到未擊倒的敗北處理對齊舊站
  # （可重新 ready 再戰"), a timed-out battle silently resets — `started_at`,
  # `attack_count`, and every `BossReady` mark are cleared — so the team
  # can ready up and fight again rather than being stuck. `ended_at` is
  # only ever written on an actual victory, so `defeated?`/`ended_at`
  # unambiguously mean "won", never "timed out".
  class BossesController < BaseController
    include Game::BossesHelper

    before_action :set_question
    before_action :set_battle
    before_action :set_time_limit
    before_action :expire_if_timed_out!

    def show
    end

    # POST /game/bosses/:number/ready — idempotent per-player readiness
    # mark (`BossReady` has a unique index on [boss_battle_id, player_id],
    # so a repeated click from the same player never inflates the count —
    # this replaces the legacy READY_COUNT integer bump, which had no such
    # guard and could be reinflated by a page refresh).
    def ready
      unless @battle.ended_at.present?
        @battle.boss_readies.find_or_create_by!(player: current_player)
        start_if_all_ready!
      end

      redirect_to game_boss_path(@question.number)
    end

    # POST /game/bosses/:number/attacks — a netizen click is worth +2
    # attacks, everyone else +1 (server-decided from `current_player.job`,
    # never trusted from the client). Rejected outright if the fight hasn't
    # started yet or is already over.
    def attacks
      if @battle.started_at.blank? || @battle.ended_at.present?
        return redirect_to game_boss_path(@question.number), alert: "尚未開戰或戰鬥已結束"
      end

      delta = current_player.netizen? ? 2 : 1
      @battle.attack_count += delta
      @battle.ended_at = Time.current if @battle.defeated?
      @battle.save!

      redirect_to game_boss_path(@question.number)
    end

    # GET /game/bosses/:number/status.json — polled from the boss page
    # itself: the lobby watches `ready`/`total`/`started`, the battle
    # screen watches `hp_percent`/`attack_count`/`defeated`. Never blocks
    # (REFACTOR_PLAN.md §0 — no legacy `while(true) + usleep`).
    def status
      render json: {
        hp_percent: @battle.hp_percent,
        attack_count: @battle.attack_count,
        ready: @battle.ready_count,
        total: current_team.players.count,
        started: @battle.started_at.present?,
        defeated: @battle.ended_at.present?
      }
    end

    private

    def set_question
      @question = Question.find_by!(number: params[:number])
    end

    def set_battle
      @battle = current_team.boss_battles.find_or_create_by!(boss_no: @question.number) do |battle|
        battle.hp = @question.boss_hp
      end
    end

    def set_time_limit
      @time_limit = boss_time_limit_seconds(@question, current_team)
    end

    def expire_if_timed_out!
      return unless @battle.started_at.present? && @battle.ended_at.blank?
      return unless Time.current > @battle.started_at + @time_limit

      @battle.update!(started_at: nil, attack_count: 0)
      @battle.boss_readies.destroy_all
      flash.now[:alert] = "王的時限已到，尚未擊敗，請重新宣戰！"
    end

    def start_if_all_ready!
      return if @battle.started_at.present?

      total = current_team.players.count
      return if total.zero? || @battle.ready_count < total

      @battle.update!(started_at: Time.current)
    end
  end
end
