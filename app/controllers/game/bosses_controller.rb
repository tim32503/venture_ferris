module Game
  # One boss fight per question (legacy `wheel/boss/{bno}`, `attack`,
  # `getBossHP`, `bossIsStart`, `teamIsReady`, `ready` — REFACTOR_PLAN.md
  # §2/P4; see model comments on BossBattle/BossReady for the persistence
  # design). `#show` renders either the ready-up lobby or the battle screen
  # depending on `@battle.started_at`; `#ready`/`#attacks` are classic
  # redirect-driven mutations (same style as Game::TeamsController /
  # Game::JobsController's `#update`, not JSON); `#status` is the only JSON
  # polling endpoint. `#skill` (docs/JOB_SKILLS_DESIGN.md) is JSON too, but
  # for a different reason — see its own comment.
  #
  # Time limit: `question.boss_time_limit` seconds, +10s if the team has an
  # uncle (REFACTOR_PLAN.md §1.2 — the legacy uncle/netizen/senior/celebrity
  # effects were all broken client-side; this ports the *intended* design,
  # not the bugs), plus `@battle.bonus_time_seconds` from 阿北's active skill.
  # Always computed server-side, never trusted from a client value.
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
  # unambiguously mean "won", never "timed out". `bonus_time_seconds`/
  # `spotlight_until` reset alongside `started_at`/`attack_count` for the
  # same reason: they're state for *this* attempt at the fight, not the
  # battle row's permanent identity (unlike `boss_skill_uses`, which stays —
  # see that model's comment on why "once per battle" survives a retry).
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
    #
    # `critical` (boss_poll_controller.js's weak-point hit) doubles that
    # delta, but the client's claim is only trusted once every
    # BossBattle::CRITICAL_THROTTLE_SECONDS (BossBattle#critical_ready?) —
    # a claim inside the throttle window is silently scored as a normal
    # attack instead of being rejected, so a spammed/faked client never
    # loses the underlying attack, just the crit bonus. That throttle is
    # itself bypassed while a 罔美 聚光燈 window is open (see
    # BossBattle#critical_ready?).
    #
    # 鞋姊 (senior)'s 醍醐灌頂 active skill forces this player's *next*
    # attack to be a critical outright, bypassing both the `critical` param
    # and the throttle — `pending_senior_skill_use` finds the unconsumed
    # `BossSkillUse` row from Game::BossesController#skill and consumes it
    # here.
    def attacks
      if @battle.started_at.blank? || @battle.ended_at.present?
        return redirect_to game_boss_path(@question.number), alert: "尚未開戰或戰鬥已結束"
      end

      now = Time.current
      pending_use = pending_senior_skill_use
      claims_critical = ActiveModel::Type::Boolean.new.cast(params[:critical])
      critical = pending_use.present? || (claims_critical && @battle.critical_ready?(now))

      base_delta = current_player.netizen? ? 2 : 1
      @battle.attack_count += critical ? base_delta * 2 : base_delta
      @battle.last_critical_at = now if critical
      @battle.ended_at = Time.current if @battle.defeated?
      @battle.save!
      pending_use&.update!(consumed_at: now)

      redirect_to game_boss_path(@question.number)
    end

    # POST /game/bosses/:number/skill — activates the current player's job's
    # Boss-fight active skill (docs/JOB_SKILLS_DESIGN.md). No parameters:
    # which skill fires and what it does are entirely decided server-side
    # from `current_player.job`, the client only expresses intent. Unlike
    # `ready`/`attacks`, this renders JSON on success too (not a redirect) —
    # the skill card needs the concrete effect (e.g. the new time limit, or
    # whether the netizen hit just defeated the boss) to animate immediately,
    # and there is no follow-up poll tick dedicated to "did my own skill
    # click just land" the way there is for attacks.
    #
    # Rejected outright (422 JSON, never a silent no-op) if: the fight hasn't
    # started or is already over, the player has no job, or the player has
    # already used their skill this battle (the `boss_skill_uses` unique
    # index on [boss_battle_id, player_id] is the actual guard against a
    # race between two requests from the same player — this action's own
    # `already_used` check is just the friendly first line).
    def skill
      return render_skill_error(:battle_not_active) if @battle.started_at.blank? || @battle.ended_at.present?
      return render_skill_error(:no_job) if current_player.job.blank?

      skill_use = @battle.boss_skill_uses.new(player: current_player, skill: current_player.job)

      begin
        skill_use.save!
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
        return render_skill_error(:already_used)
      end

      render json: { ok: true, skill: current_player.job, effect: apply_skill!(skill_use) }
    end

    # GET /game/bosses/:number/status.json — polled from the boss page
    # itself: the lobby watches `ready`/`total`/`started`, the battle
    # screen watches `hp_percent`/`attack_count`/`defeated`/
    # `bonus_time_seconds`/`spotlight_active`/`skill_available` (the last
    # three back the skill card and countdown — never trust a client-held
    # memory of "did I already use my skill", always re-derive it from the
    # DB). Never blocks (REFACTOR_PLAN.md §0 — no legacy `while(true) +
    # usleep`).
    #
    # `next_path`/`defeat_message` are only meaningful once `defeated` is
    # true, but are always computed and sent — boss_poll_controller.js reads
    # them straight off this response rather than re-deriving "where does a
    # defeated boss send the team" client-side (Game::BossesHelper
    # #boss_defeat_next_path is the single place that decision lives, shared
    # with `#show`'s own server-rendered defeated state).
    def status
      render json: {
        hp_percent: @battle.hp_percent,
        attack_count: @battle.attack_count,
        ready: @battle.ready_count,
        total: current_team.players.count,
        started: @battle.started_at.present?,
        defeated: @battle.ended_at.present?,
        next_path: boss_defeat_next_path(@question),
        defeat_message: boss_defeat_message(@question),
        bonus_time_seconds: @battle.bonus_time_seconds,
        spotlight_active: @battle.spotlight_active?,
        skill_available: boss_skill_available?(@battle, current_player)
      }
    end

    private

    def set_question
      # `includes(:boss)` because the battle screen renders the monster's
      # sprite/positioning class straight off the association.
      @question = Question.includes(:boss).find_by!(number: params[:number])
    end

    def set_battle
      @battle = current_team.boss_battles.find_or_create_by!(question: @question) do |battle|
        battle.hp = @question.boss_hp
      end
    end

    def set_time_limit
      @time_limit = boss_time_limit_seconds(@question, current_team) + @battle.bonus_time_seconds
    end

    def expire_if_timed_out!
      return unless @battle.started_at.present? && @battle.ended_at.blank?
      return unless Time.current > @battle.started_at + @time_limit

      @battle.update!(started_at: nil, attack_count: 0, bonus_time_seconds: 0, spotlight_until: nil)
      @battle.boss_readies.destroy_all
      flash.now[:alert] = "王的時限已到，尚未擊敗，請重新宣戰！"
    end

    def start_if_all_ready!
      return if @battle.started_at.present?

      total = current_team.players.count
      return if total.zero? || @battle.ready_count < total

      @battle.update!(started_at: Time.current)
    end

    def pending_senior_skill_use
      @battle.boss_skill_uses.find_by(player: current_player, skill: "senior", consumed_at: nil)
    end

    def render_skill_error(error)
      render json: { ok: false, error: error }, status: :unprocessable_entity
    end

    # Applies the concrete server-side effect for `current_player.job` and
    # returns the JSON-serializable summary `#skill` renders back to the
    # client. `skill_use` starts unconsumed (`consumed_at` nil, see the
    # migration comment); every job except senior consumes it immediately
    # here — senior's stays pending until `#attacks` consumes it on the next
    # attack (see `pending_senior_skill_use`).
    def apply_skill!(skill_use)
      case current_player.job
      when "uncle"
        @battle.update!(bonus_time_seconds: @battle.bonus_time_seconds + BossBattle::UNCLE_SKILL_BONUS_SECONDS)
        skill_use.update!(consumed_at: Time.current)
        { bonus_time_seconds: @battle.bonus_time_seconds, time_limit: current_time_limit }
      when "netizen"
        @battle.attack_count += BossBattle::NETIZEN_SKILL_DAMAGE
        @battle.ended_at = Time.current if @battle.defeated?
        @battle.save!
        skill_use.update!(consumed_at: Time.current)
        {
          damage: BossBattle::NETIZEN_SKILL_DAMAGE,
          attack_count: @battle.attack_count,
          hp_percent: @battle.hp_percent,
          defeated: @battle.ended_at.present?
        }
      when "senior"
        { pending_critical: true }
      when "celebrity"
        until_at = Time.current + BossBattle::SPOTLIGHT_SECONDS
        @battle.update!(spotlight_until: until_at)
        skill_use.update!(consumed_at: Time.current)
        { spotlight_until: until_at.iso8601, spotlight_seconds: BossBattle::SPOTLIGHT_SECONDS }
      end
    end

    def current_time_limit
      boss_time_limit_seconds(@question, current_team) + @battle.bonus_time_seconds
    end
  end
end
