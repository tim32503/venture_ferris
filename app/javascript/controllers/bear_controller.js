import { Controller } from "@hotwired/stimulus"

// Restores the legacy "spot the difference" minigame from wheel_bear.php
// (question 9's `QUESTION_PASSWORD` was an empty string in the 2018 dump —
// the legacy game judged this question entirely client-side, exactly like
// the puzzle kind; see Question#interactive? and
// Game::QuestionsController#answer). The 5 hotspots themselves are
// percentage-positioned <button> overlays rendered by the view from
// Game::QuestionsController::BEAR_HOTSPOTS (same percentage-of-image-pixels
// convention as the map hotspots in maps_controller.rb/show.html.erb) — this
// controller only tracks which ones have been found and drives the progress
// message, the confirm button, and the completion POST.
//
// Bug this fixes rather than reproduces: wheel_bear.php kept found hotspots
// in a single comma-joined string (`$('#answer')`), so a second click on
// the *same* `<area>` happily appended to it again (id "3" clicked twice ->
// "3,3" — six entries for five spots), and the check handler's per-id
// `count == 1` test then failed even though the player had genuinely found
// all 5 — which is the whole reason the legacy copy warns "請點選右下角的
// 勾勾檢查你是否有重複點選唷！" (nudging players to guess *why* it failed).
// We use a Set instead of a string, so a repeat click on an already-found
// hotspot is simply a no-op: there is no way to accidentally fail after
// genuinely finding all 5.
export default class extends Controller {
  static targets = [ "hotspot", "toast", "confirmButton", "completeSubmit" ]
  static values = { total: Number }

  connect() {
    this.found = new Set()
  }

  hotspotClick(event) {
    const id = event.currentTarget.dataset.bearHotspotId

    if (this.found.has(id)) {
      this.announce(this.progressMessage())
      return
    }

    this.found.add(id)
    event.currentTarget.classList.add("is-found")

    if (this.found.size >= this.totalValue) {
      this.announce(`恭喜！你找到 ${this.totalValue} 個不一樣的地方了！請點選下方按鈕確認答案吧！`)
      this.showConfirmButton()
    } else {
      this.announce(this.progressMessage())
    }
  }

  // The confirm button is only ever revealed once `found.size` reaches
  // `totalValue` (see hotspotClick above), and every id in `found` is one of
  // the `totalValue` real hotspots the view rendered — unlike the legacy
  // string-based version there is no way to reach this handler with an
  // incomplete or duplicated set. The size check is kept anyway as a
  // defensive guard rather than trusting the button's hidden state alone.
  confirm() {
    if (this.found.size < this.totalValue) return
    if (this.hasCompleteSubmitTarget) this.completeSubmitTarget.click()
  }

  showConfirmButton() {
    if (this.hasConfirmButtonTarget) this.confirmButtonTarget.style.display = "inline-flex"
  }

  progressMessage() {
    const remaining = this.totalValue - this.found.size
    return `恭喜！你找到 ${this.found.size} 個不一樣的地方了！還有 ${remaining} 個地方喔！`
  }

  // A page-internal toast instead of `alert()`/`confirm()` — some embedded
  // browsers suppress those outright (see the `Turbo.config.forms.confirm`
  // fix in app/javascript/application.js), so this game avoids them
  // everywhere, not just here.
  announce(message) {
    if (!this.hasToastTarget) return
    this.toastTarget.textContent = message
  }
}
