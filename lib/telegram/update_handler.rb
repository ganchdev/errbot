# frozen_string_literal: true

module Telegram
  class UpdateHandler

    START_MESSAGE = <<~TEXT.squish.freeze
      Errbot is connected and polling Telegram successfully.
      Account linking is the next step, so for now this bot only responds to /start.
    TEXT

    def initialize(client:, logger: Rails.logger)
      @client = client
      @logger = logger
    end

    def call(update)
      message = update["message"]
      return if message.blank?

      text = message["text"].to_s.strip
      return unless text.start_with?("/start")

      client.send_message(chat_id: message.dig("chat", "id"), text: START_MESSAGE)
    rescue StandardError => e
      logger.error("Telegram update handling failed for update #{update['update_id']}: #{e.message}")
      raise
    end

    private

    attr_reader :client, :logger

  end
end
