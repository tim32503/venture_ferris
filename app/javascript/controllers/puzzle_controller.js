import { Controller } from "@hotwired/stimulus"

// Wires the jQuery snapPuzzle plugin (vendor/javascript/jquery.snap-puzzle.min.js,
// loaded classic via javascript_include_tag in the layout, jQuery UI +
// touch-punch already loaded ahead of it — see REFACTOR_PLAN.md §3) onto
// the source image for puzzle-kind questions (numbers 1 and 2).
//
// Rows/columns come from `Question#puzzle_rows`/`puzzle_cols` (seeded per
// question) rather than being hardcoded, unlike the legacy
// `wheel_puzzle.php:154-158` which branched on `PUZZLE_NO == '1' | '2'`.
//
// The plugin's own `onComplete` only means the pieces snapped back into
// their original grid positions — it knows nothing about the answer text
// printed on the assembled photo. So completing the jigsaw here just
// reveals/enables the answer form beneath it; the player still has to read
// the photo and type what they found, and the server is the only thing
// that ever checks it against `answer_digest` (REFACTOR_PLAN.md §0: no
// more front-end answer comparison).
export default class extends Controller {
  static targets = [ "image", "pile", "solvedBanner", "submit" ]
  static values = {
    rows: Number,
    columns: Number
  }

  connect() {
    this.waitForLayoutThenStart()
  }

  // `image.complete` can flip to `true` before the browser has actually
  // laid the element out (a cached/fast-loading image can report
  // `complete` in the same tick Stimulus connects, ahead of the first
  // layout pass) — snapPuzzle reads `$(image).width()`/`.height()` to size
  // every piece, and measuring too early silently produces 0x0 pieces.
  // Polling with requestAnimationFrame until there's a real layout box
  // (and the classic-script jQuery plugin has finished loading) avoids
  // depending on load-event ordering at all.
  waitForLayoutThenStart() {
    const image = this.imageTarget

    const isReady = () =>
      image.complete && image.naturalWidth > 0 && image.offsetWidth > 0 &&
      window.jQuery && window.jQuery.fn.snapPuzzle

    const tick = () => {
      if (isReady()) {
        this.startPuzzle()
      } else {
        requestAnimationFrame(tick)
      }
    }

    tick()
  }

  startPuzzle() {
    window.jQuery(this.imageTarget).snapPuzzle({
      rows: this.rowsValue,
      columns: this.columnsValue,
      pile: this.pileTarget,
      containment: this.element,
      onComplete: () => this.onPuzzleComplete()
    })

    this.element.dataset.puzzleInitialized = "true"
  }

  onPuzzleComplete() {
    if (this.hasSolvedBannerTarget) this.solvedBannerTarget.hidden = false
    if (this.hasSubmitTarget) this.submitTarget.disabled = false
  }
}
