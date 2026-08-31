import { Controller } from "@hotwired/stimulus"

// Wraps a native <dialog> element to replace Bootstrap 4's jQuery-backed
// modal (data-toggle="modal"/data-dismiss="modal") on the home page's
// "玩法說明" popup. The <dialog> element already gives us Esc-to-close and
// focus handling for free — this controller only needs to open it via
// showModal() and close it on backdrop click or the close button.
export default class extends Controller {
  static targets = [ "dialog" ]

  open() {
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  // Clicking the ::backdrop area (outside <dialog>'s own padded content)
  // still fires a click on the <dialog> element itself, since the backdrop
  // is not a separate hit-testable box in the DOM. Distinguish "click landed
  // on the dialog's own box" from "click landed outside it" using the event
  // target's bounding rect.
  closeOnBackdrop(event) {
    if (event.target !== this.dialogTarget) return

    const rect = this.dialogTarget.getBoundingClientRect()
    const inside =
      event.clientX >= rect.left && event.clientX <= rect.right &&
      event.clientY >= rect.top && event.clientY <= rect.bottom

    if (!inside) this.close()
  }
}
