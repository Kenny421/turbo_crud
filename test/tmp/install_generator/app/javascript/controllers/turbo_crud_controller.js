import { Controller } from "@hotwired/stimulus"

// Optional TurboCrud behavior if your app prefers Stimulus over inline script hooks.
export default class extends Controller {
  connect() {
    this.onKeydown = this.onKeydown.bind(this)
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
  }

  onKeydown(event) {
    if (event.key !== "Escape") return

    const container = document.querySelector("[data-turbo-crud-container]")
    if (!container) return

    const closeButton = container.querySelector("[data-turbo-crud-close], .turbo-crud__modal-close, .turbo-crud__drawer-close")
    if (!closeButton) return

    event.preventDefault()
    closeButton.click()
  }
}
