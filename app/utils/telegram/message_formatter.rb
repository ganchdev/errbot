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
      when "ssl_certificate_warning"
        format_ssl_certificate_warning_message
      else
        raise ArgumentError, "Unsupported Telegram message type: #{telegram_message.message_type}"
      end
    end

    private

    attr_reader :telegram_message

    # Formats Telegram messages backed by application error events.
    #
    # @return [String]
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

    # Formats Telegram messages for uptime failures.
    #
    # @return [String]
    def format_project_down_message
      [
        "<b>Project down: #{escaped_text(uptime_check.project.name)}</b>",
        formatted_field("URL", uptime_check.project.url),
        formatted_field("Status", uptime_status_label),
        (formatted_field("SSL", ssl_status_label) if uptime_check.ssl_applicable?),
        (if uptime_check.response_time_ms.present?
           formatted_field("Response time",
                           "#{uptime_check.response_time_ms} ms")
         end),
        formatted_field("Checked", formatted_timestamp(uptime_check.checked_at))
      ].compact.join("\n")
    end

    # Formats Telegram messages for SSL certificates that are expired or close
    # to expiry.
    #
    # @return [String]
    def format_ssl_certificate_warning_message
      [
        "<b>#{escaped_text(ssl_warning_title)}: #{escaped_text(uptime_check.project.name)}</b>",
        formatted_field("URL", uptime_check.project.url),
        (formatted_field("Expires", formatted_timestamp(uptime_check.ssl_expires_at)) if uptime_check.ssl_expires_at.present?),
        (formatted_field("Time remaining", ssl_time_remaining_label) if uptime_check.ssl_expires_at.present?),
        formatted_field("Checked", formatted_timestamp(uptime_check.checked_at))
      ].compact.join("\n")
    end

    # Returns the event source for event-backed message types.
    #
    # @return [Event]
    def event
      telegram_message.source
    end

    # Returns the uptime-check source for uptime-backed message types.
    #
    # @return [UptimeCheck]
    def uptime_check
      telegram_message.source
    end

    # Resolves the human-readable event heading for event-backed alerts.
    #
    # @return [String]
    def event_reason_label
      case telegram_message.message_type
      when "reappeared_issue"
        "Issue reappeared"
      else
        "New issue"
      end
    end

    # Builds the short exception summary block for event notifications.
    #
    # @return [String]
    def event_error_summary
      [event.exception_type, event.exception_message].compact_blank.join(": ").presence || "Unknown error"
    end

    # Picks the most useful culprit string from the event payload or issue.
    #
    # @return [String, nil]
    def event_culprit
      event_culprit_from_frame || event.issue.culprit.presence
    end

    # Extracts a location string from the deepest stack frame when available.
    #
    # @return [String, nil]
    def event_culprit_from_frame
      event.stack_frames.last&.slice("abs_path", "filename", "function", "lineno")&.then do |frame|
        path = frame["abs_path"].presence || frame["filename"].presence
        next if path.blank?

        location = path.dup
        location = "#{location}:#{frame['lineno']}" if frame["lineno"].present?
        frame["function"].present? ? "#{location}:in #{frame['function']}" : location
      end
    end

    # Formats the observed uptime result for project-down notifications.
    #
    # @return [String]
    def uptime_status_label
      return "HTTP #{uptime_check.response_code}" if uptime_check.response_code.present?

      "No response"
    end

    # Chooses the title line for SSL certificate warnings.
    #
    # @return [String]
    def ssl_warning_title
      uptime_check.ssl_status == "expired" ? "SSL certificate expired" : "SSL certificate expiring soon"
    end

    # Formats the stored SSL health status for uptime notifications.
    #
    # @return [String]
    def ssl_status_label
      case uptime_check.ssl_status
      when "valid"
        "Valid"
      when "expiring_soon"
        "Expiring soon"
      when "expired"
        "Expired"
      when "error"
        uptime_check.ssl_error.presence || "Unavailable"
      else
        "N/A"
      end
    end

    # Returns a compact human-readable time-to-expiry label.
    #
    # @return [String]
    def ssl_time_remaining_label
      seconds_remaining = uptime_check.ssl_expires_at - (uptime_check.checked_at || Time.current)
      return "Expired" if seconds_remaining <= 0

      "#{(seconds_remaining / 1.day).ceil} days"
    end

    # Formats timestamps consistently for Telegram output.
    #
    # @param timestamp [Time, DateTime, nil]
    # @return [String]
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
