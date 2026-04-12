# frozen_string_literal: true

module FlashMessage
  class Component < ApplicationComponent

    prop :type, type: proc(&:to_sym)
    prop :message

    def classes
      {
        notice: "border-emerald-500/30 bg-emerald-500/10 text-emerald-900 dark:text-emerald-100",
        alert: "border-red-500/30 bg-red-500/10 text-red-900 dark:text-red-100"
      }.fetch(type, "border-zinc-300 bg-zinc-50 text-zinc-900 dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-100")
    end

  end
end
