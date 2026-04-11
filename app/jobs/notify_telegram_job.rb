# frozen_string_literal: true

# Sends a pending event notification to all linked Telegram chats.
#
# The job is intentionally delivery-only: eligibility is decided upstream
# during ingestion so retries remain isolated to Telegram send failures.
class NotifyTelegramJob < ApplicationJob

  queue_as :notifications

  retry_on Telegram::Error, wait: :polynomially_longer, attempts: 3 do |job, _error|
    Event.find_by(id: job.arguments.first)&.update!(notification_state: "failed")
  end

  # Delivers a pending notification event to all linked Telegram bot users.
  #
  # @param event_id [Integer]
  # @return [void]
  def perform(event_id)
    event = Event.includes(:project, :issue).find_by(id: event_id)
    return if event.nil? || event.notification_state != "pending"

    bot_users = BotUser.linked.includes(:authorized_user).to_a

    if bot_users.empty?
      event.update!(notification_state: "skipped")
      return
    end

    message = Telegram::NotificationFormatter.call(event)
    client = build_client

    bot_users.each do |bot_user|
      client.send_message(chat_id: bot_user.chat_id, text: message, parse_mode: "HTML")
    end

    event.update!(notification_state: "sent", notified_at: Time.current)
  end

  private

  # Builds the Telegram API client used for outbound notifications.
  #
  # @return [Telegram::Client]
  def build_client
    Telegram::Client.new(bot_token: ENV.fetch("TELEGRAM_BOT_TOKEN"), logger: Rails.logger)
  end

end
