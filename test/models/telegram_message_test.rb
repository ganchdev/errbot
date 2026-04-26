# frozen_string_literal: true

require "test_helper"

class TelegramMessageTest < ActiveSupport::TestCase

  include ActiveJob::TestHelper

  setup do
    @project = projects(:one)
    @issue = Issue.create!(
      project: @project,
      fingerprint_hash: SecureRandom.hex(16),
      title: "Telegram message issue",
      culprit: "app/services/telegram_message.rb in call",
      status: "open",
      level: "error",
      platform: "ruby",
      first_seen_at: Time.current,
      last_seen_at: Time.current,
      occurrences_count: 1
    )
    @event = Event.create!(
      project: @project,
      issue: @issue,
      event_uuid: SecureRandom.uuid,
      occurred_at: Time.current,
      environment: "production",
      release: "1.0.0",
      exception_type: "RuntimeError",
      exception_message: "boom",
      handled: false,
      level: "error",
      raw_json: "{}",
      notification_reason: "new_issue",
      notification_state: "pending"
    )
  end

  test "validates allowed message types and statuses" do
    message = TelegramMessage.new(source: @event, message_type: "not_real", status: "unknown")

    assert_not message.valid?
    assert_includes message.errors[:message_type], "is not included in the list"
    assert_includes message.errors[:status], "is not included in the list"
  end

  test "enforces unique message type per source" do
    TelegramMessage.create!(source: @event, message_type: "new_issue", status: "pending")
    duplicate = TelegramMessage.new(source: @event, message_type: "new_issue", status: "pending")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:message_type], "has already been taken"
  end

  test "enqueue_for creates and enqueues a telegram message once" do
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs

    assert_difference "TelegramMessage.count", 1 do
      assert_enqueued_jobs 1, only: NotifyTelegramJob do
        TelegramMessage.enqueue_for!(source: @event, message_type: "new_issue")
      end
    end

    assert_no_difference "TelegramMessage.count" do
      assert_no_enqueued_jobs only: NotifyTelegramJob do
        TelegramMessage.enqueue_for!(source: @event, message_type: "new_issue")
      end
    end
  end

end
