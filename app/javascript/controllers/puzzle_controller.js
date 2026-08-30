import { Controller } from "@hotwired/stimulus"

// A self-contained jigsaw engine for puzzle-kind questions (numbers 1 and 2),
// replacing the legacy jQuery/jQuery UI `jquery.snap-puzzle.min.js` (+
// touch-punch) plugin — see docs/UI_MODERNIZATION_PLAN.md decision 2 and
// docs/UI_AUDIT.md dependency table #1-#3/#7. Pointer Events unify mouse and
// touch input natively, so there is no separate touch shim.
//
// Rows/columns come from `Question#puzzle_rows`/`puzzle_cols` (seeded per
// question) rather than being hardcoded, unlike the legacy
// `wheel_puzzle.php:154-158` which branched on `PUZZLE_NO == '1' | '2'`.
//
// Reaching 100% placed IS the answer for this kind of question — puzzle
// questions are "interactive" (Question#interactive?): there is no answer
// text to compare, server-side or otherwise. This mirrors the legacy
// jquery.snap-puzzle `onComplete` in wheel_puzzle.php:197-208, which POSTed
// straight to `timer/Question/:no/End` and redirected to the boss fight —
// no answer form ever existed on that page. So `onPuzzleComplete` below
// shows a brief completion banner and then submits the hidden completion
// form itself; `Game::QuestionsController#answer` accepts it unconditionally
// for this kind (see that action's comment).
//
// Layout model: every piece is an absolutely-positioned <div> sliced from
// the source image via `background-position`/`background-size` (no canvas
// needed). Two coordinate frames:
//   - Pieces already snapped into the board are children of `board` and
//     positioned in board-relative pixels (col * cellWidth, row * cellHeight).
//   - Pieces still loose live in `pile`, laid out in a shuffled (not
//     overlapping) grid of `pileSlot` indices that wraps to however many
//     columns actually fit the pile's current width — a purely random (x, y)
//     scatter was tried first and produced heavy piece-on-piece overlap for
//     bigger grids (4x4) in a narrow column, which is bad for players and
//     made pointer hit-testing in tests land on the wrong piece.
// `layout()` recomputes cell size and every piece's pixel geometry from
// scratch — it runs at init and again on resize/orientation change, so
// scaling the window (or rotating a phone) keeps pieces aligned with their
// slots instead of only being correct at the moment they were placed.
const SNAP_THRESHOLD_RATIO = 0.4

// How long the completion banner stays on screen before the hidden form
// auto-submits — long enough to read, short enough not to feel stuck
// (roughly the legacy `fadeOut(150).fadeIn()` beat before its own POST).
const COMPLETE_SUBMIT_DELAY_MS = 900

export default class extends Controller {
  static targets = [ "image", "board", "pile", "solvedBanner", "completeSubmit" ]
  static values = {
    rows: Number,
    columns: Number
  }

  connect() {
    this.pieces = []
    this.placedCount = 0
    this.boundLayout = () => this.layout()
    this.waitForLayoutThenStart()
  }

  disconnect() {
    window.removeEventListener("resize", this.boundLayout)
    window.removeEventListener("orientationchange", this.boundLayout)
    if (this.completeTimeout) window.clearTimeout(this.completeTimeout)
  }

  // `image.complete` can flip to `true` before the browser has actually
  // laid the element out (a cached/fast-loading image can report
  // `complete` in the same tick Stimulus connects, ahead of the first
  // layout pass) — sizing pieces off `image.offsetWidth`/`offsetHeight` too
  // early would silently produce 0x0 geometry. Polling with
  // requestAnimationFrame until there's a real layout box avoids depending
  // on load-event ordering at all (this was a real bug the first time this
  // controller was written against the jQuery plugin).
  waitForLayoutThenStart() {
    const image = this.imageTarget

    const isReady = () =>
      image.complete && image.naturalWidth > 0 && image.offsetWidth > 0

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
    const image = this.imageTarget
    this.rows = this.rowsValue
    this.columns = this.columnsValue
    this.imageUrl = image.currentSrc || image.src

    // Pin the board's aspect ratio to the source image so board-relative
    // percentages/pixels always line up with the picture, regardless of how
    // wide the surrounding column ends up being.
    this.boardTarget.style.aspectRatio = `${image.naturalWidth} / ${image.naturalHeight}`

    this.buildSlots()
    this.buildPieces()
    this.layout()

    window.addEventListener("resize", this.boundLayout)
    window.addEventListener("orientationchange", this.boundLayout)

    this.element.dataset.puzzleInitialized = "true"
  }

  buildSlots() {
    for (let row = 0; row < this.rows; row++) {
      for (let col = 0; col < this.columns; col++) {
        const slot = document.createElement("div")
        slot.className = "puzzle-slot"
        slot.dataset.row = row
        slot.dataset.col = col
        this.boardTarget.appendChild(slot)
      }
    }
  }

  buildPieces() {
    const slotOrder = this.shuffled([ ...Array(this.rows * this.columns).keys() ])
    let index = 0

    for (let row = 0; row < this.rows; row++) {
      for (let col = 0; col < this.columns; col++) {
        const piece = document.createElement("div")
        piece.className = "puzzle-piece"
        piece.dataset.row = row
        piece.dataset.col = col
        piece.dataset.locked = "false"
        // Starting position in the pile: a shuffled grid slot (not the
        // piece's own row/col) so pieces start visibly scrambled without
        // overlapping each other.
        piece.dataset.pileSlot = slotOrder[index]
        index++
        piece.style.backgroundImage = `url(${this.imageUrl})`
        piece.style.touchAction = "none"

        piece.addEventListener("pointerdown", (event) => this.onPointerDown(event, piece))

        this.pileTarget.appendChild(piece)
        this.pieces.push(piece)
      }
    }
  }

  shuffled(array) {
    const result = array.slice()
    for (let i = result.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1))
      ;[ result[i], result[j] ] = [ result[j], result[i] ]
    }
    return result
  }

  // Recomputes every piece's pixel size/position from the current board and
  // pile geometry. Safe to call any number of times (init, resize,
  // orientationchange) — it never depends on prior calls.
  layout() {
    if (!this.rows || !this.columns) return

    const boardRect = this.boardTarget.getBoundingClientRect()
    const cellWidth = boardRect.width / this.columns
    const cellHeight = boardRect.height / this.rows
    this.cellWidth = cellWidth
    this.cellHeight = cellHeight

    this.boardTarget.querySelectorAll(".puzzle-slot").forEach((slot) => {
      const row = Number(slot.dataset.row)
      const col = Number(slot.dataset.col)
      slot.style.left = `${col * cellWidth}px`
      slot.style.top = `${row * cellHeight}px`
      slot.style.width = `${cellWidth}px`
      slot.style.height = `${cellHeight}px`
    })

    const pileRect = this.pileTarget.getBoundingClientRect()
    const perRow = Math.max(1, Math.floor(pileRect.width / cellWidth))
    const pileRows = Math.ceil(this.pieces.length / perRow)
    // The pile only holds pieces via `position: absolute` children, which
    // don't contribute to its natural height — reserve enough height
    // ourselves so the whole scattered grid is visible instead of being
    // clipped by the CSS `min-height: 200px` floor.
    this.pileTarget.style.minHeight = `${pileRows * cellHeight}px`

    this.pieces.forEach((piece) => {
      if (piece.dataset.dragging === "true") return

      piece.style.width = `${cellWidth}px`
      piece.style.height = `${cellHeight}px`
      piece.style.backgroundSize = `${cellWidth * this.columns}px ${cellHeight * this.rows}px`
      piece.style.backgroundPosition =
        `${-Number(piece.dataset.col) * cellWidth}px ${-Number(piece.dataset.row) * cellHeight}px`

      if (piece.dataset.locked === "true") {
        piece.style.left = `${Number(piece.dataset.col) * cellWidth}px`
        piece.style.top = `${Number(piece.dataset.row) * cellHeight}px`
      } else {
        const slot = Number(piece.dataset.pileSlot)
        piece.style.left = `${(slot % perRow) * cellWidth}px`
        piece.style.top = `${Math.floor(slot / perRow) * cellHeight}px`
      }
    })
  }

  onPointerDown(event, piece) {
    if (piece.dataset.locked === "true") return
    event.preventDefault()

    const pointerId = event.pointerId

    // Reparenting the piece to <body> (below) so it can travel over both
    // columns unclipped moves it out from under the cursor for a moment,
    // and Chrome drops `setPointerCapture` when its target is relocated
    // mid-gesture — so instead of trusting capture to keep routing events
    // to `piece`, listen on `window` (every pointermove/pointerup bubbles
    // there no matter which element the cursor ends up over) and filter by
    // `pointerId` to stay scoped to this one gesture. `setPointerCapture`
    // is still requested best-effort — harmless when it works, ignored
    // when the browser revokes it.
    try { piece.setPointerCapture(pointerId) } catch { /* not essential */ }

    piece.dataset.dragging = "true"
    piece.classList.add("is-dragging")

    const pieceRect = piece.getBoundingClientRect()
    const offsetX = event.clientX - pieceRect.left
    const offsetY = event.clientY - pieceRect.top

    // Reparent to <body> as `position: fixed` for the duration of the drag
    // so the piece can travel freely across the pile/board columns without
    // being clipped by either container's `overflow: hidden`, using plain
    // viewport coordinates from the pointer event.
    document.body.appendChild(piece)
    piece.style.position = "fixed"
    piece.style.width = `${this.cellWidth}px`
    piece.style.height = `${this.cellHeight}px`
    piece.style.left = `${event.clientX - offsetX}px`
    piece.style.top = `${event.clientY - offsetY}px`
    piece.style.zIndex = "1000"

    const onMove = (moveEvent) => {
      if (moveEvent.pointerId !== pointerId) return
      piece.style.left = `${moveEvent.clientX - offsetX}px`
      piece.style.top = `${moveEvent.clientY - offsetY}px`
    }

    const cleanup = () => {
      window.removeEventListener("pointermove", onMove)
      window.removeEventListener("pointerup", onUp)
      window.removeEventListener("pointercancel", onCancel)
      piece.style.position = ""
      piece.style.zIndex = ""
      piece.classList.remove("is-dragging")
      piece.dataset.dragging = "false"
    }

    const onUp = (upEvent) => {
      if (upEvent.pointerId !== pointerId) return
      cleanup()
      this.finishDrag(piece, upEvent.clientX - offsetX, upEvent.clientY - offsetY)
    }

    const onCancel = (cancelEvent) => {
      if (cancelEvent.pointerId !== pointerId) return
      cleanup()
      this.pileTarget.appendChild(piece)
      this.layout()
    }

    window.addEventListener("pointermove", onMove)
    window.addEventListener("pointerup", onUp)
    window.addEventListener("pointercancel", onCancel)
  }

  // `pieceLeft`/`pieceTop` are the piece's top-left corner in viewport
  // pixels at drop time (matching the `position: fixed` frame it was
  // dragged in). Decides whether it snapped into its own correct slot, and
  // reparents it into whichever container (board or pile) it now belongs to.
  //
  // `onPointerDown` already refuses to start a new drag on a piece that's
  // `locked`, so this shouldn't normally run twice for the same piece — but
  // bail defensively rather than letting a stray/duplicate call re-drop an
  // already-placed piece back into the pile while leaving it marked locked.
  finishDrag(piece, pieceLeft, pieceTop) {
    if (piece.dataset.locked === "true") return

    const boardRect = this.boardTarget.getBoundingClientRect()
    const pieceCenterX = pieceLeft + this.cellWidth / 2
    const pieceCenterY = pieceTop + this.cellHeight / 2

    const row = Number(piece.dataset.row)
    const col = Number(piece.dataset.col)
    const targetCenterX = boardRect.left + (col + 0.5) * this.cellWidth
    const targetCenterY = boardRect.top + (row + 0.5) * this.cellHeight

    const distance = Math.hypot(pieceCenterX - targetCenterX, pieceCenterY - targetCenterY)
    const threshold = Math.min(this.cellWidth, this.cellHeight) * SNAP_THRESHOLD_RATIO

    if (distance <= threshold) {
      piece.dataset.locked = "true"
      piece.classList.add("is-locked")
      this.boardTarget.appendChild(piece)
      this.placedCount += 1
      this.layout()

      if (this.placedCount >= this.rows * this.columns) {
        this.onPuzzleComplete()
      }
      return
    }

    // Missed the slot: spring back to its assigned spot in the pile's
    // scattered grid (its `pileSlot` from buildPieces() never changes).
    // Explicitly keep `locked` in sync with where the piece actually lives —
    // it was already "false" on every real path here, but this makes the
    // invariant (locked ⇒ parented in board) hold even under a stray retry.
    piece.dataset.locked = "false"
    this.pileTarget.appendChild(piece)
    this.layout()
  }

  // Puzzle questions are `interactive?` (see Question#interactive?): a
  // fully-placed grid IS the answer, so this fires the completion POST
  // itself instead of unlocking an answer form for the player to fill in —
  // there is no answer text to type. `completeSubmitTarget` is the submit
  // control of a hidden `form_with url: answer_game_question_path(...)` in
  // puzzle.html.erb; clicking it drives a real form submission (Turbo Drive
  // handles the resulting redirect to the boss fight the same way it does
  // for every other question kind's answer form).
  onPuzzleComplete() {
    if (this.hasSolvedBannerTarget) this.solvedBannerTarget.hidden = false

    this.completeTimeout = window.setTimeout(() => {
      if (this.hasCompleteSubmitTarget) this.completeSubmitTarget.click()
    }, COMPLETE_SUBMIT_DELAY_MS)
  }
}
