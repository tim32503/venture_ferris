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
// Attacking itself is a plain `button_to` POST (Turbo handles the
// redirect+re-render), not an ajax call from this controller — the click
// updating the DOM comes from that full round trip, not from this poller.
export default class extends PollController {
  static targets = [ "readyCount", "readyTotal", "hpBar", "hpText", "attackCount", "counter" ]
  static values = {
    started: Boolean,
    scoreUrl: String,
    timeLimit: Number,
    startedAtMs: Number
  }

  connect() {
    super.connect()
    this.wasStarted = this.startedValue
    this.startCountdown()
  }

  disconnect() {
    super.disconnect()
    if (this.countdownTimer) clearInterval(this.countdownTimer)
  }

  onData(data) {
    if (data.defeated) {
      window.location.href = this.scoreUrlValue
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
}
