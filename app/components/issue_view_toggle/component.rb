# frozen_string_literal: true

module IssueViewToggle
  class Component < ApplicationComponent

    prop :left_label
    prop :right_label
    prop :left_view, default: -> { "stacktrace" }
    prop :right_view, default: -> { "event-json" }
    prop :default_view, default: -> { "stacktrace" }

  end
end
