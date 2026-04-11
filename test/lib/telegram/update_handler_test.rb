# frozen_string_literal: true

require "test_helper"

module Telegram
  class UpdateHandlerTest < ActiveSupport::TestCase

    test "start command replies to the chat" do
      client = FakeClient.new
      handler = UpdateHandler.new(client: client, logger: Logger.new(nil))
      update = { "update_id" => 12, "message" => { "text" => "/start", "chat" => { "id" => 999 } } }

      handler.call(update)

      assert_equal 999, client.messages.first[:chat_id]
      assert_match("Errbot is connected", client.messages.first[:text])
    end

    test "non start messages are ignored" do
      client = FakeClient.new
      handler = UpdateHandler.new(client: client, logger: Logger.new(nil))
      update = { "update_id" => 13, "message" => { "text" => "hello", "chat" => { "id" => 999 } } }

      handler.call(update)

      assert_empty client.messages
    end

    class FakeClient

      attr_reader :messages

      def initialize
        @messages = []
      end

      def send_message(chat_id:, text:)
        @messages << { chat_id: chat_id, text: text }
      end

    end

  end
end
