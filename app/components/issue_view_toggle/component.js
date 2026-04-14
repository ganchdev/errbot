import { Controller } from "@hotwired/stimulus";

export default class IssueViewToggleController extends Controller {
  static targets = ["button"];
  static values = { defaultView: { type: String, default: "stacktrace" } };

  connect() {
    this.setActiveView(this.defaultViewValue);
  }

  show(event) {
    event.preventDefault();
    this.setActiveView(event.currentTarget.dataset.view);
  }

  setActiveView(activeView) {
    this.buttonTargets.forEach((button) => {
      const selected = button.dataset.view === activeView;
      button.setAttribute("aria-pressed", selected ? "true" : "false");
      button.classList.toggle("bg-white", selected);
      button.classList.toggle("text-zinc-950", selected);
      button.classList.toggle("shadow-sm", selected);
      button.classList.toggle("dark:bg-zinc-950", selected);
      button.classList.toggle("dark:text-zinc-50", selected);
      button.classList.toggle("text-zinc-500", !selected);
      button.classList.toggle("dark:text-zinc-400", !selected);
    });

    this.panels.forEach((panel) => {
      panel.hidden = panel.dataset.issueViewPanel !== activeView;
    });
  }

  get panels() {
    const container = this.element.closest("[data-issue-view-container]");
    if (!container) return [];

    return Array.from(container.querySelectorAll("[data-issue-view-panel]"));
  }
}
