# frozen_string_literal: true

# Sends a pending Telegram notification to all linked Telegram chats.
#
# The job is intentionally delivery-only: message eligibility is decided
# upstream so retries remain isolated to Telegram send failures.
class NotifyTelegramJob < ApplicationJob

  queue_as :notifications

  retry_on Telegram::Error, wait: :polynomially_longer, attempts: 3 do |job, _error|
    TelegramMessage.find_by(id: job.arguments.first)&.update!(status: "failed")
  end

  # Delivers a pending Telegram message to all linked bot users.
  #
  # @param telegram_message_id [Integer]
  # @return [void]
  def perform(telegram_message_id)
    telegram_message = TelegramMessage.find_by(id: telegram_message_id)

    return if telegram_message.nil? || telegram_message.status != "pending"
    return telegram_message.update!(status: "skipped") if telegram_message.source.nil?

    bot_users = BotUser.linked.includes(:authorized_user).to_a

    if bot_users.empty?
      telegram_message.update!(status: "skipped")
      return
    end

    message = Telegram::MessageFormatter.call(telegram_message)
    client = build_client

    bot_users.each do |bot_user|
      client.send_message(chat_id: bot_user.chat_id, text: message, parse_mode: "HTML")
    end

    telegram_message.update!(status: "sent", sent_at: Time.current)
  end

  private

  # Builds the Telegram API client used for outbound notifications.
  #
  # @return [Telegram::Client]
  def build_client
    Telegram::Client.new(bot_token: ENV.fetch("TELEGRAM_BOT_TOKEN"), logger: Rails.logger)
  end

end
