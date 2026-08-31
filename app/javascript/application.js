// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import { Turbo } from "@hotwired/turbo-rails"
import "controllers"

// data-turbo-confirm defaults to window.confirm, which some embedded
// browsers suppress (the dialog never shows, confirm resolves false, and
// the form submit is silently cancelled). Render our own in-page dialog
// so confirmations behave the same everywhere.
// Dialog look follows docs/UI_STYLE_GUIDE.md's <dialog> recipe (dark
// adventure card + amber primary button), kept in sync by hand since the
// classes only exist as string literals here for Tailwind's scanner to pick up.
Turbo.config.forms.confirm = (message) => {
  return new Promise((resolve) => {
    const overlay = document.createElement("div")
    overlay.setAttribute("data-turbo-temporary", "")
    overlay.className = "fixed inset-0 z-[2000] flex items-center justify-center bg-black/50"
    overlay.innerHTML = `
      <div class="rounded-xl bg-slate-800 p-6 text-center ring-1 ring-white/10 shadow-2xl" style="max-width:22rem;width:90%;">
        <p class="mb-4 text-slate-100"></p>
        <div class="flex justify-center gap-3">
          <button type="button" class="rounded-lg bg-amber-500 px-4 py-2 font-semibold text-slate-900 hover:bg-amber-400" data-confirm-accept>確認</button>
          <button type="button" class="rounded-lg bg-slate-700 px-4 py-2 font-semibold text-slate-100 ring-1 ring-white/10 hover:bg-slate-600" data-confirm-cancel>取消</button>
        </div>
      </div>`
    overlay.querySelector("p").textContent = message
    const close = (result) => { overlay.remove(); resolve(result) }
    overlay.querySelector("[data-confirm-accept]").addEventListener("click", () => close(true))
    overlay.querySelector("[data-confirm-cancel]").addEventListener("click", () => close(false))
    document.body.appendChild(overlay)
  })
}
