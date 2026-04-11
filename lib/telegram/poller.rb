# frozen_string_literal: true

require "telegram/client"

module Telegram
  class Poller

    DEFAULT_TIMEOUT_SECONDS = 20
    DEFAULT_BACKOFF_SECONDS = 5

    def initialize(client:, handler:, logger: Rails.logger, timeout: DEFAULT_TIMEOUT_SECONDS,
                   error_backoff: DEFAULT_BACKOFF_SECONDS)
      @client = client
      @handler = handler
      @logger = logger
      @timeout = timeout
      @error_backoff = error_backoff
      @next_offset = nil
      @running = true
    end

    def run
      logger.info("Starting Telegram polling loop")

      run_once while running?
    rescue Interrupt
      logger.info("Stopping Telegram polling loop")
    end

    def run_once
      updates = client.get_updates(offset: next_offset, timeout: timeout)

      updates.each do |update|
        handler.call(update)
        @next_offset = update.fetch("update_id") + 1
      end
    rescue Telegram::Error => e
      logger.error("Telegram polling failed: #{e.message}")
      sleep(error_backoff)
    end

    def stop
      @running = false
    end

    private

    attr_reader :client, :error_backoff, :handler, :logger, :next_offset, :timeout

    def running?
      @running
    end

  end
end
