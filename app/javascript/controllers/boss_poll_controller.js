import PollController from "controllers/poll_controller"

// Polls `GET /game/bosses/:number/status.json` from the boss page itself
// (REFACTOR_PLAN.md P4 — legacy `bossIsStart()`/`getBossHP()` polling loops
// in wheel_boss.php, replaced with the same non-blocking client poll used
// everywhere else in this app). Keeps three things live for a teammate who
// didn't click anything themselves:
//   - the ready-lobby's ready/total counters
//   - the battle screen's HP bar / attack count
//   - the lobby <-> battle <-> defeated transitions (`data.started` /
//     `data.defeated`), which are two different server-rendered templates
//     (BossesController#show branches on `@battle`), so those transitions
//     just reload/redirect rather than trying to swap DOM in place.
//
// Attacking (see `#attack` below) is a `fetch()` POST straight to the same
// `attacks` action the old `button_to` used — deliberately *not* a normal
// Turbo-intercepted form submission. A `button_to`/`form_with` submission is
// a full Turbo Drive "visit": it replaces the whole page body on every
// single click, which would blow away all of the client-side hit-feedback
// state this controller now owns (combo counter, weak-point timers, the
// in-flight damage-number/shake animations). `fetch()` keeps the page alive
// across attacks; the poll above is what keeps the HP bar / attack count
// eventually correct against the server's authoritative numbers. The
// server-side win/loss and scoring logic is untouched — this only changes
// the transport, not what gets decided where.
export default class extends PollController {
  static targets = [
    "readyCount", "readyTotal", "hpBar", "hpText", "attackCount", "counter", "stage", "monster", "fx", "combo",
    "skillCard", "skillButton", "skillButtonLabel"
  ]
  static values = {
    started: Boolean,
    scoreUrl: String,
    timeLimit: Number,
    startedAtMs: Number,
    attacksUrl: String,
    isNetizen: Boolean,
    // Job-skill wiring (docs/JOB_SKILLS_DESIGN.md). `skillUrl` is blank and
    // `job` empty for a player with no job — `activateSkill` no-ops in that
    // case, matching the view only rendering the skill card at all when
    // `current_player.job.present?`.
    skillUrl: String,
    job: String,
    skillAvailable: Boolean,
    spotlightActive: Boolean
  }

  // Presentational tuning for the weak-point spot: how long it stays
  // visible, and the gap (measured from despawn to next spawn) before it
  // reappears elsewhere. Kept well above BossBattle::CRITICAL_THROTTLE_SECONDS
  // (2s) so a player who reacts promptly essentially never gets an honest
  // critical throttled away server-side.
  static WEAK_POINT_VISIBLE_MS_MIN = 1500
  static WEAK_POINT_VISIBLE_MS_MAX = 2000
  static WEAK_POINT_GAP_MS_MIN = 2500
  static WEAK_POINT_GAP_MS_MAX = 4500
  static COMBO_RESET_MS = 1500
  static DEFEAT_DELAY_MS = 900

  connect() {
    super.connect()
    this.wasStarted = this.startedValue
    this.startCountdown()

    this.comboCount = 0
    this.weakPointEl = null
    this.defeating = false
    this.seniorCharged = false
    this.skillPending = false

    if (this.hasHpBarTarget) this.updateHpColor()
    if (this.hasStageTarget && this.hasFxTarget) this.scheduleWeakPoint()
    if (this.hasStageTarget) this.setSpotlightVisual(this.spotlightActiveValue)
  }

  disconnect() {
    super.disconnect()
    if (this.countdownTimer) clearInterval(this.countdownTimer)
    if (this.weakPointSpawnTimer) clearTimeout(this.weakPointSpawnTimer)
    if (this.weakPointHideTimer) clearTimeout(this.weakPointHideTimer)
    if (this.comboResetTimer) clearTimeout(this.comboResetTimer)
    if (this.spotlightEndTimer) clearTimeout(this.spotlightEndTimer)
  }

  onData(data) {
    if (data.defeated) {
      // `next_path` is server-decided (Game::BossesHelper#boss_defeat_next_path)
      // — a first-phase victory goes to the next phase's question page
      // (auto_start there picks up the timer on its own), everything else
      // goes to the score page. Falls back to the score URL the view
      // already renders if a stale poll response predates `next_path`.
      const destination = data.next_path || this.scoreUrlValue
      this.playDefeatSequence(() => { window.location.href = destination }, data.defeat_message)
      return
    }

    if (data.started !== this.wasStarted) {
      window.location.reload()
      return
    }

    if (this.hasReadyCountTarget) this.readyCountTarget.textContent = data.ready
    if (this.hasReadyTotalTarget) this.readyTotalTarget.textContent = data.total
    if (this.hasHpBarTarget) this.hpBarTarget.style.width = `${data.hp_percent}%`
    if (this.hasHpTextTarget) this.hpTextTarget.textContent = data.hp_percent
    if (this.hasAttackCountTarget) this.attackCountTarget.textContent = data.attack_count
    this.updateHpColor(data.hp_percent)

    // Server truth wins over any client memory of "did I already use my
    // skill" (docs/JOB_SKILLS_DESIGN.md — never trust the client for this).
    // Also picks up a teammate's own skill use (e.g. 罔美's spotlight) even
    // on a device that never clicked anything itself.
    if (this.hasSkillButtonTarget && typeof data.skill_available === "boolean") {
      this.skillButtonTarget.disabled = !data.skill_available
      if (this.hasSkillButtonLabelTarget && !this.skillPending) {
        this.skillButtonLabelTarget.textContent = data.skill_available ? "發動技能" : "已使用"
      }
    }
    if (typeof data.spotlight_active === "boolean") this.setSpotlightVisual(data.spotlight_active)
  }

  // Click/keyboard(Enter/Space, native to <button>) handler for the monster
  // itself and for a currently-visible weak-point marker (both wire
  // `data-action="click->boss-poll#attack"` — see spawnWeakPoint below).
  // Plays all the local hit feedback immediately (optimistic — the next
  // poll tick reconciles the real numbers), then reports the hit to the
  // server, which alone decides the actual damage/victory.
  attack(event) {
    const weakPointHit = event.target.closest && event.target.closest(".weak-point")
    // 鞋姊 (senior)'s 醍醐灌頂 forces this attack to critical server-side
    // regardless of whether it landed on a weak point (Game::BossesController
    // #attacks' `pending_senior_skill_use`) — mirror that locally so the hit
    // feedback (doubled damage number) matches what the server is about to
    // record, and consume the local "charged" flag/visual the same way the
    // server consumes the pending BossSkillUse row.
    const seniorForcedCritical = this.seniorCharged
    const isCritical = !!weakPointHit || seniorForcedCritical

    // Order matters: `ripple` reads `event.currentTarget.getBoundingClientRect()`,
    // which returns an all-zero rect once the element is detached — so every
    // feedback effect that needs the clicked element still in the DOM runs
    // before despawning the weak point.
    this.ripple(event)
    this.playHitFlash()
    this.spawnDamageNumber(event, isCritical)
    this.bumpCombo()

    if (weakPointHit) this.despawnWeakPoint({ reschedule: true })
    if (seniorForcedCritical) this.clearSkillCharge()

    this.sendAttack(isCritical)
  }

  // Click feedback shared by the monster button and the weak-point marker —
  // purely presentational, wired up to the `.ripple`/`.rippleEffect`
  // keyframes in boss.scss (previously used only by the old "攻擊！" button).
  // Creates a short-lived ripple span at the click point and lets the CSS
  // animation size/fade it, then removes the span once the animation ends
  // so repeated clicks don't pile up detached nodes.
  ripple(event) {
    const button = event.currentTarget
    if (!button || typeof button.getBoundingClientRect !== "function") return

    const rect = button.getBoundingClientRect()
    const size = Math.max(rect.width, rect.height)
    const span = document.createElement("span")
    span.className = "ripple rippleEffect"
    span.style.width = `${size}px`
    span.style.height = `${size}px`
    span.style.left = `${event.clientX - rect.left - size / 2}px`
    span.style.top = `${event.clientY - rect.top - size / 2}px`
    span.addEventListener("animationend", () => span.remove())
    button.appendChild(span)
  }

  playHitFlash() {
    if (!this.hasMonsterTarget) return
    this.monsterTarget.classList.remove("hit-flash")
    // Force a reflow so re-adding the class restarts the CSS animation even
    // when clicks land faster than the animation's own duration.
    void this.monsterTarget.offsetWidth
    this.monsterTarget.classList.add("hit-flash")
  }

  spawnDamageNumber(event, isCritical) {
    if (!this.hasFxTarget) return

    const rect = this.fxTarget.getBoundingClientRect()
    const x = event.clientX - rect.left
    const y = event.clientY - rect.top
    const base = this.isNetizenValue ? 2 : 1
    const amount = isCritical ? base * 2 : base

    this.renderDamageNumber(x, y, amount, isCritical)
  }

  // Shared by the click-driven `spawnDamageNumber` above and 鄉民 (netizen)'s
  // 肉搜公審 skill effect (`playNetizenSkillEffect` below), which has no
  // click event to read a position from.
  renderDamageNumber(x, y, amount, isCritical) {
    if (!this.hasFxTarget) return

    const span = document.createElement("span")
    span.className = isCritical ? "dmg-number crit" : "dmg-number"
    span.textContent = `+${amount}`
    span.style.left = `${x}px`
    span.style.top = `${y}px`
    span.addEventListener("animationend", () => span.remove())
    this.fxTarget.appendChild(span)
  }

  bumpCombo() {
    this.comboCount += 1
    if (this.hasComboTarget) {
      this.comboTarget.textContent = this.comboCount > 1 ? `${this.comboCount} 連擊！` : ""
      this.comboTarget.classList.toggle("show", this.comboCount > 1)
    }

    if (this.comboResetTimer) clearTimeout(this.comboResetTimer)
    this.comboResetTimer = setTimeout(() => {
      this.comboCount = 0
      if (this.hasComboTarget) this.comboTarget.classList.remove("show")
    }, this.constructor.COMBO_RESET_MS)
  }

  updateHpColor(percent) {
    if (!this.hasHpBarTarget) return

    const value = percent !== undefined ? percent : parseFloat(this.hpBarTarget.style.width)
    this.hpBarTarget.classList.remove("bg-emerald-500!", "bg-amber-500!", "bg-rose-500!")

    if (Number.isNaN(value) || value > 50) {
      this.hpBarTarget.classList.add("bg-emerald-500!")
    } else if (value > 20) {
      this.hpBarTarget.classList.add("bg-amber-500!")
    } else {
      this.hpBarTarget.classList.add("bg-rose-500!")
    }
  }

  // `message` is the server's `defeat_message` (Game::BossesHelper
  // #boss_defeat_message) — present only for a first-phase victory, where
  // it names what's coming next (the final-phase fight) rather than just
  // celebrating the hit. Absent for every other boss, leaving just the
  // plain "撃破！" banner.
  playDefeatSequence(callback, message) {
    if (this.defeating) return
    this.defeating = true

    if (this.weakPointSpawnTimer) clearTimeout(this.weakPointSpawnTimer)
    if (this.weakPointHideTimer) clearTimeout(this.weakPointHideTimer)
    if (this.hasMonsterTarget) this.monsterTarget.classList.add("defeated")

    if (this.hasFxTarget) {
      const banner = document.createElement("div")
      banner.className = "victory-banner"

      const headline = document.createElement("div")
      headline.textContent = "撃破！"
      banner.appendChild(headline)

      if (message) {
        const sub = document.createElement("div")
        sub.className = "victory-banner-sub"
        sub.textContent = message
        banner.appendChild(sub)
      }

      this.fxTarget.appendChild(banner)
    }

    setTimeout(callback, this.constructor.DEFEAT_DELAY_MS)
  }

  // Presentational only — the server independently resets a timed-out
  // fight the next time any boss endpoint is hit (BossesController
  // #expire_if_timed_out!), so a clock drift here never lets a fight run
  // longer than the server allows.
  startCountdown() {
    if (!this.hasCounterTarget || !this.startedAtMsValue) return

    this.countdownTimer = setInterval(() => {
      const elapsedSeconds = (Date.now() - this.startedAtMsValue) / 1000
      const remaining = Math.max(0, Math.ceil(this.timeLimitValue - elapsedSeconds))
      this.counterTarget.textContent = remaining
    }, 500)
  }

  // ---- weak-point spot ----
  //
  // A random, briefly-visible "critical" target inside the stage. Its
  // schedule is purely a front-end presentation concern (BossBattle's own
  // CRITICAL_THROTTLE_SECONDS throttle is the actual anti-cheat gate — see
  // Game::BossesController#attacks); this timer only decides *when the
  // player is invited to try*.

  // `scheduleWeakPoint`/`spawnWeakPoint` both defensively clear *both*
  // timers (and any existing element) before setting their own, so the
  // "exactly one pending timer, exactly one visible marker" invariant holds
  // no matter which path triggered them — the natural alternation
  // (schedule -> spawn -> despawn(reschedule) -> schedule -> ...),
  // `attack()`'s despawn-on-hit, or `forceWeakPointForTest` jumping the
  // queue. Without this, forcing a spawn while a natural one was already
  // pending left the earlier timer uncancelled — it would fire later and
  // spawn a second, untracked marker that never gets removed (found via
  // manual QA: repeated forced spawns during dev-server testing left
  // several `.weak-point` markers stacked on the monster at once).
  scheduleWeakPoint() {
    this.clearWeakPointTimers()
    const gap = this.randomBetween(this.constructor.WEAK_POINT_GAP_MS_MIN, this.constructor.WEAK_POINT_GAP_MS_MAX)
    this.weakPointSpawnTimer = setTimeout(() => this.spawnWeakPoint(), gap)
  }

  spawnWeakPoint() {
    if (!this.hasFxTarget) return
    this.clearWeakPointTimers()
    if (this.weakPointEl) {
      this.weakPointEl.remove()
      this.weakPointEl = null
    }

    const el = document.createElement("div")
    el.className = "weak-point"
    el.dataset.action = "click->boss-poll#attack"
    el.style.left = `${20 + Math.random() * 60}%`
    el.style.top = `${15 + Math.random() * 55}%`
    this.fxTarget.appendChild(el)
    this.weakPointEl = el

    const visibleMs = this.randomBetween(this.constructor.WEAK_POINT_VISIBLE_MS_MIN, this.constructor.WEAK_POINT_VISIBLE_MS_MAX)
    this.weakPointHideTimer = setTimeout(() => this.despawnWeakPoint({ reschedule: true }), visibleMs)
  }

  despawnWeakPoint({ reschedule }) {
    this.clearWeakPointTimers()
    if (this.weakPointEl) {
      this.weakPointEl.remove()
      this.weakPointEl = null
    }
    if (reschedule && !this.defeating) this.scheduleWeakPoint()
  }

  clearWeakPointTimers() {
    if (this.weakPointSpawnTimer) {
      clearTimeout(this.weakPointSpawnTimer)
      this.weakPointSpawnTimer = null
    }
    if (this.weakPointHideTimer) {
      clearTimeout(this.weakPointHideTimer)
      this.weakPointHideTimer = null
    }
  }

  randomBetween(min, max) {
    return min + Math.random() * (max - min)
  }

  // Test hook (see test/system/game_boss_page_test.rb): the weak-point spot
  // is on a random timer by design, which system tests can't wait on
  // reliably. Rather than shrinking the real timers for every environment
  // (which would also change the anti-cheat throttle's safety margin in
  // production), tests reach the live controller instance via
  // `window.Stimulus.getControllerForElementAndIdentifier(...)` (exposed by
  // controllers/application.js) and call this directly to force a
  // deterministic, immediately-clickable weak point. `spawnWeakPoint`
  // itself clears any pending timers/element first, so this is safe to call
  // regardless of what the natural schedule is currently doing.
  forceWeakPointForTest() {
    this.spawnWeakPoint()
    return this.weakPointEl
  }

  // ---- attack transport ----

  async sendAttack(isCritical) {
    if (!this.hasAttacksUrlValue) return

    try {
      await fetch(this.attacksUrlValue, {
        method: "POST",
        credentials: "same-origin",
        redirect: "manual",
        headers: {
          "X-CSRF-Token": this.csrfToken(),
          "Content-Type": "application/x-www-form-urlencoded"
        },
        body: new URLSearchParams({ critical: isCritical ? "1" : "0" })
      })
    } catch (error) {
      // A single failed click should not break the game — the next poll
      // tick still reconciles hp/attack_count against the server, and the
      // player can simply click again.
      console.error("attack failed", error)
    }
  }

  csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : null
  }

  // ---- job active skill (docs/JOB_SKILLS_DESIGN.md) ----
  //
  // POST /game/bosses/:number/skill, click-triggered from the skill card
  // (`data-action="click->boss-poll#activateSkill"`). Unlike `sendAttack`
  // this reads the JSON response body — the four job effects need their
  // concrete numbers (the new time limit, the actual damage dealt, whether
  // it defeated the boss) to animate correctly, and there's no dedicated
  // poll tick for "did my own click just land" the way there is for a plain
  // attack. Server-decided end to end: this never guesses which job the
  // player has or what the effect does, it only plays back what `#skill`
  // reports.
  async activateSkill() {
    if (!this.hasSkillUrlValue || !this.skillUrlValue || this.skillPending) return

    this.skillPending = true
    if (this.hasSkillButtonTarget) this.skillButtonTarget.disabled = true

    try {
      const response = await fetch(this.skillUrlValue, {
        method: "POST",
        credentials: "same-origin",
        headers: {
          "X-CSRF-Token": this.csrfToken(),
          "Accept": "application/json"
        }
      })
      const data = await response.json()

      if (data.ok) {
        this.setSkillButtonLabel("已使用")
        this.playSkillEffect(data.skill, data.effect || {})
      } else {
        // Rejected (already used elsewhere, battle ended, etc. — see
        // Game::BossesController#skill). The next poll tick's
        // `skill_available` is the actual source of truth for whether the
        // button re-enables; this label is just an immediate explanation.
        this.setSkillButtonLabel(this.skillErrorLabel(data.error))
      }
    } catch (error) {
      console.error("skill activation failed", error)
      if (this.hasSkillButtonTarget) this.skillButtonTarget.disabled = false
    } finally {
      this.skillPending = false
    }
  }

  setSkillButtonLabel(text) {
    if (this.hasSkillButtonLabelTarget) this.skillButtonLabelTarget.textContent = text
  }

  skillErrorLabel(error) {
    const labels = {
      already_used: "已使用",
      battle_not_active: "尚未開戰",
      no_job: "尚未選擇職業"
    }
    return labels[error] || "無法使用"
  }

  playSkillEffect(job, effect) {
    switch (job) {
      case "uncle": return this.playUncleSkillEffect(effect)
      case "netizen": return this.playNetizenSkillEffect(effect)
      case "senior": return this.playSeniorSkillEffect(effect)
      case "celebrity": return this.playCelebritySkillEffect(effect)
    }
  }

  // 阿北 倚老賣老: the countdown jumps up by the reported new limit — the
  // running countdown (`startCountdown` above) reads `timeLimitValue` on
  // every tick, so updating it here is enough for the jump to show on the
  // very next 500ms tick without waiting for a poll round trip.
  playUncleSkillEffect(effect) {
    if (typeof effect.time_limit === "number") this.timeLimitValue = effect.time_limit

    if (this.hasCounterTarget) {
      this.counterTarget.classList.remove("counter-bump")
      void this.counterTarget.offsetWidth
      this.counterTarget.classList.add("counter-bump")
    }
  }

  // 鄉民 肉搜公審: an immediate 5-damage hit with no click of its own to hang
  // feedback off of, so the damage number spawns at the stage's center and
  // the HP bar/attack count are set straight from the server's numbers
  // (optimistic update — the next poll tick would reconcile these anyway).
  playNetizenSkillEffect(effect) {
    this.playHitFlash()

    if (this.hasFxTarget) {
      const rect = this.fxTarget.getBoundingClientRect()
      this.renderDamageNumber(rect.width / 2, rect.height / 2, effect.damage, true)
    }

    if (this.hasAttackCountTarget && typeof effect.attack_count === "number") {
      this.attackCountTarget.textContent = effect.attack_count
    }
    if (typeof effect.hp_percent === "number") {
      if (this.hasHpBarTarget) this.hpBarTarget.style.width = `${effect.hp_percent}%`
      if (this.hasHpTextTarget) this.hpTextTarget.textContent = effect.hp_percent
      this.updateHpColor(effect.hp_percent)
    }

    if (effect.defeated) this.playDefeatSequence(() => { window.location.href = this.scoreUrlValue })
  }

  // 鞋姊 醍醐灌頂: nothing changes on the boss itself yet — this only arms
  // `this.seniorCharged`, consumed by the player's next `attack()` click
  // (see there), and shows a "charged" glow on the monster in the meantime
  // so the player can see the buff is live.
  playSeniorSkillEffect() {
    this.seniorCharged = true
    if (this.hasMonsterTarget) this.monsterTarget.classList.add("skill-charged")
  }

  clearSkillCharge() {
    this.seniorCharged = false
    if (this.hasMonsterTarget) this.monsterTarget.classList.remove("skill-charged")
  }

  // 罔美 聚光燈: reveals a weak point immediately (jumping the natural
  // schedule the same way `forceWeakPointForTest` does) and lights up the
  // stage for the reported window — `setSpotlightVisual` also runs off
  // every poll tick's `spotlight_active`, so a teammate who didn't click
  // anything still sees the window (and its close) on their own screen.
  playCelebritySkillEffect(effect) {
    this.spawnWeakPoint()
    this.setSpotlightVisual(true)

    if (this.spotlightEndTimer) clearTimeout(this.spotlightEndTimer)
    const seconds = typeof effect.spotlight_seconds === "number" ? effect.spotlight_seconds : 5
    this.spotlightEndTimer = setTimeout(() => this.setSpotlightVisual(false), seconds * 1000)
  }

  setSpotlightVisual(active) {
    if (this.hasStageTarget) this.stageTarget.classList.toggle("spotlight-active", !!active)
  }
}
