# frozen_string_literal: true

require "active_support/tagged_logging"

require "telegram/client"
require "telegram/poller"
require "telegram/update_handler"

module Telegram

  def self.run
    $stdout.sync = true

    logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new($stdout))
    logger.level = Rails.logger.level

    bot_token = ENV.fetch("TELEGRAM_BOT_TOKEN", nil)
    if bot_token.nil? || bot_token.empty?
      logger.info("Skipping Telegram polling: TELEGRAM_BOT_TOKEN is not set")
      sleep
    end

    timeout = ENV.fetch("TELEGRAM_POLL_TIMEOUT", Poller::DEFAULT_TIMEOUT_SECONDS).to_i
    error_backoff = ENV.fetch("TELEGRAM_POLL_ERROR_BACKOFF", Poller::DEFAULT_BACKOFF_SECONDS).to_i

    client = Client.new(bot_token: bot_token, logger: logger)
    handler = UpdateHandler.new(client: client, logger: logger)

    Poller.new(
      client: client,
      handler: handler,
      logger: logger,
      timeout: timeout,
      error_backoff: error_backoff
    ).run
  end

end
