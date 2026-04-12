import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button", "status"]
  static values = { copiedLabel: { type: String, default: "Copied" } }

  async copy() {
    const text = this.sourceTarget.textContent.trim()

    try {
      await navigator.clipboard.writeText(text)
      this.buttonTarget.textContent = this.copiedLabelValue
      this.statusTarget.textContent = "Code copied to clipboard."
      window.setTimeout(() => {
        this.buttonTarget.textContent = "Copy code"
        this.statusTarget.textContent = ""
      }, 2000)
    } catch (_error) {
      this.statusTarget.textContent = "Copy failed. Please copy the code manually."
    }
  }
}
