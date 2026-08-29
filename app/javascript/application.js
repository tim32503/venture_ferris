// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import { Turbo } from "@hotwired/turbo-rails"
import "controllers"

// data-turbo-confirm defaults to window.confirm, which some embedded
// browsers suppress (the dialog never shows, confirm resolves false, and
// the form submit is silently cancelled). Render our own in-page dialog
// so confirmations behave the same everywhere.
Turbo.config.forms.confirm = (message) => {
  return new Promise((resolve) => {
    const overlay = document.createElement("div")
    overlay.setAttribute("data-turbo-temporary", "")
    overlay.style.cssText =
      "position:fixed;inset:0;background:rgba(0,0,0,.5);display:flex;align-items:center;justify-content:center;z-index:2000;"
    overlay.innerHTML = `
      <div class="card" style="max-width:22rem;width:90%;">
        <div class="card-body text-center">
          <p class="mb-3"></p>
          <button type="button" class="btn btn-dark mr-2" data-confirm-accept>確認</button>
          <button type="button" class="btn btn-secondary" data-confirm-cancel>取消</button>
        </div>
      </div>`
    overlay.querySelector("p").textContent = message
    const close = (result) => { overlay.remove(); resolve(result) }
    overlay.querySelector("[data-confirm-accept]").addEventListener("click", () => close(true))
    overlay.querySelector("[data-confirm-cancel]").addEventListener("click", () => close(false))
    document.body.appendChild(overlay)
  })
}
