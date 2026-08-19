import { Controller } from "@hotwired/stimulus"

// Lightweight echo of the legacy "spot the difference" interaction in
// wheel_bear.php (`$('area').on('click', ...)` collecting 5 hotspot ids
// against the mascot photo). The seed content for question 9 rewrote the
// challenge as a plain read-a-number scavenger hunt (db/seeds.rb,
// QUESTION_SEEDS number: 9) rather than a difference-spotting minigame, so
// there is no hotspot set left to reproduce faithfully — this just gives
// the mascot photo a "tap to inspect closely" toggle before falling
// through to the same server-checked text answer form the quiz view uses.
export default class extends Controller {
  static targets = [ "image" ]

  connect() {
    this.element.dataset.bearReady = "true"
  }

  toggleZoom() {
    this.imageTarget.classList.toggle("bear-zoomed")
  }
}
