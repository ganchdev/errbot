# frozen_string_literal: true

require "cgi"

module Telegram
  # Formats a compact, safe Telegram message for supported notification types.
  class MessageFormatter

    # Builds a formatted notification message for the provided Telegram message.
    #
    # @param telegram_message [TelegramMessage]
    # @return [String]
    def self.call(telegram_message)
      new(telegram_message).call
    end

    # @param telegram_message [TelegramMessage]
    def initialize(telegram_message)
      @telegram_message = telegram_message
    end

    # Renders the outbound Telegram message body.
    #
    # @return [String]
    def call
      case telegram_message.message_type
      when "new_issue", "reappeared_issue"
        format_event_message
      when "project_down"
        format_project_down_message
      else
        raise ArgumentError, "Unsupported Telegram message type: #{telegram_message.message_type}"
      end
    end

    private

    attr_reader :telegram_message

    def format_event_message
      [
        "<b>#{escaped_text(event_reason_label)} in #{escaped_text(event.project.name)}</b>",
        (escaped_text(event_culprit) if event_culprit.present?),
        "<pre>#{escaped_text(event_error_summary)}</pre>",
        (formatted_field("Environment", event.environment) if event.environment.present?),
        (formatted_field("Release", event.release) if event.release.present?),
        formatted_field("Occurred", formatted_timestamp(event.occurred_at))
      ].compact.join("\n")
    end

    def format_project_down_message
      [
        "<b>Project down: #{escaped_text(uptime_check.project.name)}</b>",
        formatted_field("URL", uptime_check.project.url),
        formatted_field("Status", uptime_status_label),
        (if uptime_check.response_time_ms.present?
           formatted_field("Response time",
                           "#{uptime_check.response_time_ms} ms")
         end),
        formatted_field("Checked", formatted_timestamp(uptime_check.checked_at))
      ].compact.join("\n")
    end

    def event
      telegram_message.source
    end

    def uptime_check
      telegram_message.source
    end

    def event_reason_label
      case telegram_message.message_type
      when "reappeared_issue"
        "Issue reappeared"
      else
        "New issue"
      end
    end

    def event_error_summary
      [event.exception_type, event.exception_message].compact_blank.join(": ").presence || "Unknown error"
    end

    def event_culprit
      event_culprit_from_frame || event.issue.culprit.presence
    end

    def event_culprit_from_frame
      event.stack_frames.last&.slice("abs_path", "filename", "function", "lineno")&.then do |frame|
        path = frame["abs_path"].presence || frame["filename"].presence
        next if path.blank?

        location = path.dup
        location = "#{location}:#{frame['lineno']}" if frame["lineno"].present?
        frame["function"].present? ? "#{location}:in #{frame['function']}" : location
      end
    end

    def uptime_status_label
      return "HTTP #{uptime_check.response_code}" if uptime_check.response_code.present?

      "No response"
    end

    def formatted_timestamp(timestamp)
      (timestamp || Time.current).utc.strftime("%Y-%m-%d %H:%M UTC")
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
