# frozen_string_literal: true

require "test_helper"

module Telegram
  class NotificationFormatterTest < ActiveSupport::TestCase

    test "formats a new issue notification" do
      event = build_event(reason: "new_issue")

      message = NotificationFormatter.call(event)

      assert_match "<b>New issue in #{event.project.name}</b>", message
      assert_match "app/services/formatter.rb:42:in call", message
      assert_match "<pre>RuntimeError: boom</pre>", message
      assert_match "<b>Environment:</b> development", message
      assert_match "<b>Release:</b> test", message
      assert_match "<b>Occurred:</b> 2026-04-11 10:30 UTC", message
    end

    test "formats a reappeared notification without blank environment" do
      event = build_event(reason: "reappeared", environment: nil)

      message = NotificationFormatter.call(event)

      assert_match "<b>Issue reappeared in #{event.project.name}</b>", message
      refute_match "<b>Environment:</b>", message
    end

    test "escapes html-sensitive characters" do
      event = build_event(
        reason: "new_issue",
        issue_title: "boom <bad> & worse",
        exception_message: "boom <bad> & worse"
      )

      message = NotificationFormatter.call(event)

      assert_match "&lt;bad&gt; &amp; worse", message
    end

    private

    def build_event(reason:, environment: "development", issue_title: "Formatter issue", exception_message: "boom")
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

      Event.create!(
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
        notification_reason: reason
      )
    end

  end
end
