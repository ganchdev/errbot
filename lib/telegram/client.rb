# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Telegram

  class Error < StandardError; end

  class Client

    API_BASE_URL = "https://api.telegram.org"

    def initialize(bot_token:, base_url: API_BASE_URL, logger: Rails.logger)
      @bot_token = bot_token
      @base_url = base_url
      @logger = logger
    end

    def get_updates(offset: nil, timeout: 20, allowed_updates: ["message"])
      payload = { timeout: timeout, allowed_updates: allowed_updates }
      payload[:offset] = offset if offset

      request("getUpdates", payload)
    end

    # Sends a message to a Telegram chat.
    #
    # @param chat_id [String, Integer]
    # @param text [String]
    # @param options [Hash]
    # @return [Hash]
    def send_message(chat_id:, text:, **options)
      request("sendMessage", { chat_id: chat_id, text: text }.merge(options))
    end

    private

    attr_reader :base_url, :bot_token, :logger

    def request(method_name, payload)
      uri = URI.parse("#{base_url}/bot#{bot_token}/#{method_name}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(payload)

      response = http.request(request)
      body = response.body.presence || "{}"
      parsed_body = JSON.parse(body)

      raise Error, "Telegram API request failed with HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
      raise Error, parsed_body.fetch("description", "Telegram API request failed") unless parsed_body["ok"]

      parsed_body.fetch("result")
    rescue JSON::ParserError => e
      logger.error("Telegram API returned invalid JSON: #{e.message}")
      raise Error, "Telegram API returned invalid JSON"
    end

  end

end
