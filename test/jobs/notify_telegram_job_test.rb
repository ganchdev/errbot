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
  end

  test "sends pending event notifications to all linked bot users" do
    event = create_event!
    first_user = create_linked_bot_user("111")
    second_user = create_linked_bot_user("222", authorized_users(:two))
    fake_client = FakeClient.new
    job = TestNotifyTelegramJob.new(fake_client)

    job.perform(event.id)

    event.reload
    delivered_chat_ids = fake_client.messages.map { |message| message[:chat_id] }
    delivered_text = fake_client.messages.first[:text]

    assert_equal "sent", event.notification_state
    assert event.notified_at.present?
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

  test "marks event skipped when there are no linked bot users" do
    event = create_event!

    NotifyTelegramJob.perform_now(event.id)

    event.reload
    assert_equal "skipped", event.notification_state
    assert_nil event.notified_at
  end

  test "ignores events that are not pending" do
    event = create_event!(notification_state: "sent", notified_at: Time.current)

    NotifyTelegramJob.perform_now(event.id)

    event.reload
    assert_equal "sent", event.notification_state
  end

  private

  def create_event!(notification_state: "pending", notification_reason: "new_issue", notified_at: nil)
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
      notification_reason: notification_reason,
      notified_at: notified_at
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

  class TestNotifyTelegramJob < NotifyTelegramJob

    def initialize(client)
      super()
      @client = client
    end

    private

    def build_client
      @client
    end

  end

end
