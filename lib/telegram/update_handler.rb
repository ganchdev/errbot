# frozen_string_literal: true

require "uri"

module Telegram
  class UpdateHandler

    def initialize(client:, logger: Rails.logger)
      @client = client
      @logger = logger
    end

    def call(update)
      message = update["message"]
      return if message.blank?

      text = message["text"].to_s.strip
      chat_id = message.dig("chat", "id")
      return if chat_id.blank?

      if text.start_with?("/start")
        handle_start(chat_id)
      elsif email_address?(text)
        handle_email(chat_id, text)
      elsif verification_code?(text)
        handle_code(chat_id, text)
      else
        handle_fallback(chat_id)
      end
    rescue StandardError => e
      logger.error("Telegram update handling failed for update #{update['update_id']}: #{e.message}")
      raise
    end

    private

    attr_reader :client, :logger

    def handle_start(chat_id)
      bot_user = BotUser.find_linked_by_chat_id(chat_id)

      if bot_user
        client.send_message(
          chat_id: chat_id,
          text: "Your Telegram account is already linked to #{bot_user.authorized_user.email_address}."
        )
      else
        client.send_message(
          chat_id: chat_id,
          text: "Send your authorized email address to begin linking your Errbot account."
        )
      end
    end

    def handle_email(chat_id, email)
      authorized_user = AuthorizedUser.find_by(email_address: email.downcase)

      unless authorized_user
        client.send_message(
          chat_id: chat_id,
          text: "That email address is not authorized. Please try again with an approved account."
        )
        return
      end

      client.send_message(
        chat_id: chat_id,
        text: "Open this link, sign in with Google, and then send me the 6-digit code:\n" \
              "#{verification_link(chat_id, email)}"
      )
    end

    def handle_code(chat_id, code)
      bot_user = BotUser.confirm_link!(chat_id: chat_id, code: code)

      if bot_user
        client.send_message(
          chat_id: chat_id,
          text: "Linked successfully. Alerts for #{bot_user.authorized_user.email_address} " \
                "are now authorized on this chat."
        )
      else
        client.send_message(
          chat_id: chat_id,
          text: "That code is invalid or expired. Send your email address again to get a fresh verification link."
        )
      end
    end

    def handle_fallback(chat_id)
      client.send_message(
        chat_id: chat_id,
        text: "Send /start to begin, your authorized email address to request a link, " \
              "or a 6-digit verification code to finish linking."
      )
    end

    def email_address?(text)
      URI::MailTo::EMAIL_REGEXP.match?(text)
    end

    def verification_code?(text)
      /\A\d{6}\z/.match?(text)
    end

    def verification_link(chat_id, email)
      app_uri = URI.parse(ENV.fetch("APP_HOST"))

      Rails.application.routes.url_helpers.bot_verify_url(
        chat_id: chat_id,
        email: email.downcase,
        host: app_uri.host,
        protocol: app_uri.scheme,
        port: app_uri.port
      )
    rescue KeyError
      raise "APP_HOST must be configured for Telegram account linking"
    end

  end
end
