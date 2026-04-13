# frozen_string_literal: true

module CopyButton
  class Component < ApplicationComponent

    prop :label, default: -> { "Copy" }
    prop :copied_label, default: -> { "Copied" }

  end
end
