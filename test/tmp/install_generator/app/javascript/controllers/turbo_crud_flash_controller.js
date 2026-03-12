import { Controller } from "@hotwired/stimulus"

// Handles flash dismiss + optional auto-hide.
export default class extends Controller {
  static values = { autoHideMs: Number }

  connect() {
    this.scheduleAutoHide()
  }

  dismiss(event) {
    const flash = event.target.closest(".turbo-crud__flash")
    if (!flash) return
    flash.remove()
  }

  scheduleAutoHide() {
    if (!this.hasAutoHideMsValue || this.autoHideMsValue <= 0) return

    this.clearTimer()
    this.timer = window.setTimeout(() => {
      this.element.innerHTML = ""
    }, this.autoHideMsValue)
  }

  disconnect() {
    this.clearTimer()
  }

  clearTimer() {
    if (!this.timer) return
    window.clearTimeout(this.timer)
    this.timer = null
  }
}
