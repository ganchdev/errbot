# frozen_string_literal: true

module StatusBadge
  class Component < ApplicationComponent

    prop :status, type: proc(&:to_s)

    def label
      status.tr("_", " ").capitalize
    end

    def classes
      {
        "open" => "border-orange-500/30 bg-orange-500/15 text-orange-700 dark:text-orange-200",
        "resolved" => "border-emerald-500/30 bg-emerald-500/15 text-emerald-700 dark:text-emerald-200",
        "ignored" => "border-zinc-400/30 bg-zinc-500/10 text-zinc-700 dark:text-zinc-200"
      }.fetch(status, "border-zinc-400/30 bg-zinc-500/10 text-zinc-700 dark:text-zinc-200")
    end

  end
end
