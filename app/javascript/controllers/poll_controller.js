import { Controller } from "@hotwired/stimulus"
import { get } from "lib/api"

// Base class for the game flow's client-side polling (REFACTOR_PLAN.md §0/§2):
// the legacy site polled the *server* in a blocking `while(true) + usleep`
// loop (e.g. `Wheel_model#getTeamNM`, `#checkUserJob`). This replaces that
// with a plain client-side `setInterval` against a non-blocking JSON
// endpoint. Subclasses (team_poll_controller, job_poll_controller) only need
// to implement `onData(json)`.
//
// Not meant to be used directly via `data-controller="poll"` — it has no
// `url` of its own to poll.
// Polling must never wait longer than 500ms between ticks.
const MAX_INTERVAL_MS = 500

export default class extends Controller {
  static values = {
    url: String,
    interval: { type: Number, default: MAX_INTERVAL_MS }
  }

  connect() {
    this.element.dataset.polling = "true"

    const interval = Math.min(this.intervalValue || MAX_INTERVAL_MS, MAX_INTERVAL_MS)
    this.timer = setInterval(() => this.poll(), interval)
    this.poll()
  }

  disconnect() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }

    delete this.element.dataset.polling
  }

  async poll() {
    if (!this.urlValue) return

    try {
      const data = await get(this.urlValue)
      this.onData(data)
    } catch (error) {
      // A single failed tick (network hiccup, brief 401 during navigation,
      // ...) should not stop the polling loop.
      console.error("poll failed", error)
    }
  }

  // Override in subclasses.
  onData(_data) {}
}
