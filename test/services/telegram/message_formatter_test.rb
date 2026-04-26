# frozen_string_literal: true

require "test_helper"

module Telegram
  class MessageFormatterTest < ActiveSupport::TestCase

    test "formats a new issue notification" do
      event_message = build_event_message(message_type: "new_issue")

      message = MessageFormatter.call(event_message)

      assert_match "<b>New issue in #{event_message.source.project.name}</b>", message
      assert_match "app/services/formatter.rb:42:in call", message
      assert_match "<pre>RuntimeError: boom</pre>", message
      assert_match "<b>Environment:</b> development", message
      assert_match "<b>Release:</b> test", message
      assert_match "<b>Occurred:</b> 2026-04-11 10:30 UTC", message
    end

    test "formats a reappeared issue notification without blank environment" do
      event_message = build_event_message(message_type: "reappeared_issue", environment: nil)

      message = MessageFormatter.call(event_message)

      assert_match "<b>Issue reappeared in #{event_message.source.project.name}</b>", message
      refute_match "<b>Environment:</b>", message
    end

    test "formats a project down notification with a response code" do
      uptime_message = build_uptime_message(response_code: 503, response_time_ms: 245)

      message = MessageFormatter.call(uptime_message)

      assert_match "<b>Project down: #{uptime_message.source.project.name}</b>", message
      assert_match "<b>URL:</b> https://example.com/health", message
      assert_match "<b>Status:</b> HTTP 503", message
      assert_match "<b>SSL:</b> Valid", message
      assert_match "<b>Response time:</b> 245 ms", message
      assert_match "<b>Checked:</b> 2026-04-11 10:30 UTC", message
    end

    test "formats a project down notification without a response code" do
      uptime_message = build_uptime_message(response_code: nil, ssl_status: "error", ssl_error: "handshake failure")

      message = MessageFormatter.call(uptime_message)

      assert_match "<b>Status:</b> No response", message
      assert_match "<b>SSL:</b> handshake failure", message
    end

    test "formats an ssl certificate warning notification" do
      uptime_message = build_uptime_message(
        response_code: 200,
        ssl_status: "expiring_soon",
        ssl_expires_at: Time.utc(2026, 4, 20, 10, 30, 0)
      )
      uptime_message.update!(message_type: "ssl_certificate_warning")

      message = MessageFormatter.call(uptime_message)

      assert_match "<b>SSL certificate expiring soon: #{uptime_message.source.project.name}</b>", message
      assert_match "<b>URL:</b> https://example.com/health", message
      assert_match "<b>Expires:</b> 2026-04-20 10:30 UTC", message
      assert_match "<b>Time remaining:</b> 9 days", message
    end

    test "escapes html-sensitive characters in event and uptime messages" do
      event_message = build_event_message(
        message_type: "new_issue",
        issue_title: "boom <bad> & worse",
        exception_message: "boom <bad> & worse"
      )
      uptime_message = build_uptime_message(project_name: "API <bad> & worse", url: "https://example.com?a=<b>")

      event_text = MessageFormatter.call(event_message)
      uptime_text = MessageFormatter.call(uptime_message)

      assert_match "&lt;bad&gt; &amp; worse", event_text
      assert_match "API &lt;bad&gt; &amp; worse", uptime_text
      assert_match "https://example.com?a=&lt;b&gt;", uptime_text
    end

    private

    # rubocop:disable Layout/LineLength
    def build_event_message(message_type:, environment: "development", issue_title: "Formatter issue", exception_message: "boom")
      project = projects(:one)
      issue = Issue.create!(
        project: project,
        fingerprint_hash: SecureRandom.hex(16),
        title: issue_title,
        culprit: "app/services/formatter.rb in call",
        status: "open",
        level: "error",
        platform: "ruby",
        first_seen_at: Time.current,
        last_seen_at: Time.current,
        occurrences_count: 1
      )

      event = Event.create!(
        project: project,
        issue: issue,
        event_uuid: SecureRandom.uuid,
        occurred_at: Time.utc(2026, 4, 11, 10, 30, 0),
        environment: environment,
        release: "test",
        exception_type: "RuntimeError",
        exception_message: exception_message,
        handled: false,
        level: "error",
        raw_json: '{"exception":{"type":"RuntimeError","value":"boom","stacktrace":{"frames":[{"filename":"app/services/formatter.rb","function":"call","lineno":42,"in_app":true}]}}}',
        notification_state: "pending",
        notification_reason: message_type == "reappeared_issue" ? "reappeared" : "new_issue"
      )

      TelegramMessage.create!(source: event, message_type: message_type, status: "pending")
    end

    def build_uptime_message(response_code: nil,
                             response_time_ms: 132,
                             project_name: "Storefront API",
                             url: "https://example.com/health",
                             ssl_status: "valid",
                             ssl_expires_at: Time.utc(2026, 5, 11, 10, 30, 0),
                             ssl_error: nil)
      project = Project.create!(
        name: project_name,
        slug: "uptime-#{SecureRandom.hex(4)}",
        ingest_token: SecureRandom.hex(32),
        default_environment: "production",
        url: url
      )
      uptime_check = UptimeCheck.create!(
        project: project,
        status: "down",
        checked_at: Time.utc(2026, 4, 11, 10, 30, 0),
        response_code: response_code,
        response_time_ms: response_time_ms,
        ssl_status: ssl_status,
        ssl_expires_at: ssl_expires_at,
        ssl_error: ssl_error
      )

      TelegramMessage.create!(source: uptime_check, message_type: "project_down", status: "pending")
    end
    # rubocop:enable Layout/LineLength

  end
end
