# frozen_string_literal: true

require "test_helper"

class NotifyTelegramJobTest < ActiveJob::TestCase

  setup do
    @project = projects(:one)
    @issue = Issue.create!(
      project: @project,
      fingerprint_hash: SecureRandom.hex(16),
      title: "Test issue",
      culprit: "app/services/test_notifier.rb in perform",
      status: "open",
      level: "error",
      platform: "ruby",
      first_seen_at: Time.current,
      last_seen_at: Time.current,
      occurrences_count: 1
    )
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs
  end

  test "sends pending telegram messages to all linked bot users" do
    telegram_message = create_event_message!
    first_user = create_linked_bot_user("111")
    second_user = create_linked_bot_user("222", authorized_users(:two))
    fake_client = FakeClient.new
    TestNotifyTelegramJob.client = fake_client

    TestNotifyTelegramJob.perform_now(telegram_message.id)

    telegram_message.reload
    delivered_chat_ids = fake_client.messages.map { |message| message[:chat_id] }
    delivered_text = fake_client.messages.first[:text]

    assert_equal "sent", telegram_message.status
    assert telegram_message.sent_at.present?
    assert_equal [first_user.chat_id, second_user.chat_id], delivered_chat_ids
    assert_match "<b>New issue in #{@project.name}</b>", delivered_text
    assert_match "app/services/test_notifier.rb in perform", delivered_text
    assert_match "<pre>", delivered_text
    assert_equal "HTML", fake_client.messages.first[:parse_mode]
  end

  test "fake client supports future send options shape" do
    client = FakeClient.new

    client.send_message(chat_id: "111", text: "hello", parse_mode: "Markdown")

    assert_equal "Markdown", client.messages.first[:parse_mode]
  end

  test "marks telegram message skipped when there are no linked bot users" do
    telegram_message = create_event_message!

    NotifyTelegramJob.perform_now(telegram_message.id)

    telegram_message.reload
    assert_equal "skipped", telegram_message.status
    assert_nil telegram_message.sent_at
  end

  test "ignores telegram messages that are not pending" do
    telegram_message = create_event_message!(status: "sent", sent_at: Time.current)

    NotifyTelegramJob.perform_now(telegram_message.id)

    telegram_message.reload
    assert_equal "sent", telegram_message.status
  end

  test "marks telegram message failed when telegram delivery exhausts retries" do
    telegram_message = create_event_message!
    create_linked_bot_user("111")
    fake_client = RaisingClient.new
    TestNotifyTelegramJob.client = fake_client

    perform_enqueued_jobs do
      TestNotifyTelegramJob.perform_later(telegram_message.id)
    end

    telegram_message.reload
    assert_equal "failed", telegram_message.status
    assert_nil telegram_message.sent_at
  end

  private

  def create_event!(notification_state: "pending", notification_reason: "new_issue")
    Event.create!(
      project: @project,
      issue: @issue,
      event_uuid: SecureRandom.uuid,
      occurred_at: Time.current,
      environment: "development",
      release: "smoke-test",
      exception_type: "RuntimeError",
      exception_message: "boom",
      handled: false,
      level: "error",
      raw_json: "{}",
      notification_state: notification_state,
      notification_reason: notification_reason
    )
  end

  def create_event_message!(status: "pending", message_type: "new_issue", sent_at: nil)
    event = create_event!(notification_reason: message_type == "reappeared_issue" ? "reappeared" : "new_issue")

    TelegramMessage.create!(
      source: event,
      message_type: message_type,
      status: status,
      sent_at: sent_at
    )
  end

  def create_linked_bot_user(chat_id, authorized_user = authorized_users(:one))
    bot_user = BotUser.begin_verification!(chat_id: chat_id, authorized_user: authorized_user)
    bot_user.complete_link!
    bot_user
  end

  class FakeClient

    attr_reader :messages

    def initialize
      @messages = []
    end

    def send_message(chat_id:, text:, **options)
      @messages << { chat_id: chat_id, text: text, **options }
    end

  end

  class RaisingClient

    def send_message(**)
      raise Telegram::Error, "boom"
    end

  end

  class TestNotifyTelegramJob < NotifyTelegramJob
    class_attribute :client

    private

    def build_client
      self.class.client
    end

  end

end
