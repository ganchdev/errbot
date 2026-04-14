# frozen_string_literal: true

require "cgi"

module Telegram
  # Formats a compact, safe Telegram message for an event notification.
  class NotificationFormatter

    # Builds a formatted notification message for the provided event.
    #
    # @param event [Event]
    # @return [String]
    def self.call(event)
      new(event).call
    end

    # @param event [Event]
    def initialize(event)
      @event = event
    end

    # Renders the outbound Telegram message body.
    #
    # @return [String]
    def call
      [
        "<b>#{escaped_text(reason_label)} in #{escaped_text(event.project.name)}</b>",
        (formatted_culprit if culprit.present?),
        "<pre>#{escaped_text(error_summary)}</pre>",
        (formatted_field("Environment", event.environment) if event.environment.present?),
        (formatted_field("Release", event.release) if event.release.present?),
        formatted_field("Occurred", formatted_occurred_at)
        # TODO: Append the issue detail URL here once the app has an /issues/:id route
        # and a stable base URL helper for deep links.
      ].compact.join("\n")
    end

    private

    attr_reader :event

    # @return [String]
    def reason_label
      case event.notification_reason
      when "reappeared"
        "Issue reappeared"
      else
        "New issue"
      end
    end

    # @return [String]
    def error_summary
      [event.exception_type, event.exception_message].compact_blank.join(": ").presence || "Unknown error"
    end

    def culprit
      culprit_from_frame || event.issue.culprit.presence
    end

    def culprit_from_frame
      event.stack_frames.last&.slice("abs_path", "filename", "function", "lineno")&.then do |frame|
        path = frame["abs_path"].presence || frame["filename"].presence
        next if path.blank?

        location = path.dup
        location = "#{location}:#{frame['lineno']}" if frame["lineno"].present?
        frame["function"].present? ? "#{location}:in #{frame['function']}" : location
      end
    end

    def formatted_culprit
      escaped_text(culprit)
    end

    # @return [String]
    def formatted_occurred_at
      (event.occurred_at || Time.current).utc.strftime("%Y-%m-%d %H:%M UTC")
    end

    # @param label [String]
    # @param value [String]
    # @return [String]
    def formatted_field(label, value)
      "<b>#{escaped_text(label)}:</b> #{escaped_text(value)}"
    end

    # @param value [Object]
    # @return [String]
    def escaped_text(value)
      CGI.escapeHTML(value.to_s)
    end

  end
end
