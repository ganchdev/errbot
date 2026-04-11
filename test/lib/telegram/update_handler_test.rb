# frozen_string_literal: true

require "test_helper"

module Telegram
  class UpdateHandlerTest < ActiveSupport::TestCase

    test "start command asks for an email when the chat is not linked" do
      client = FakeClient.new
      handler = UpdateHandler.new(client: client, logger: Logger.new(nil))
      update = { "update_id" => 12, "message" => { "text" => "/start", "chat" => { "id" => 999 } } }

      handler.call(update)

      assert_equal 999, client.messages.first[:chat_id]
      assert_match("Send your authorized email address", client.messages.first[:text])
    end

    test "authorized email sends the verification link" do
      client = FakeClient.new
      handler = UpdateHandler.new(client: client, logger: Logger.new(nil))
      update = {
        "update_id" => 13,
        "message" => { "text" => authorized_users(:one).email_address, "chat" => { "id" => 999 } }
      }

      with_app_host("http://example.com") do
        handler.call(update)
      end

      assert_match("/bot/verify?chat_id=999", client.messages.first[:text])
    end

    test "verification code completes the link" do
      client = FakeClient.new
      handler = UpdateHandler.new(client: client, logger: Logger.new(nil))
      bot_user = BotUser.begin_verification!(chat_id: "999", authorized_user: authorized_users(:one))
      update = { "update_id" => 14, "message" => { "text" => bot_user.code, "chat" => { "id" => 999 } } }

      handler.call(update)

      assert_match("Linked successfully", client.messages.first[:text])
      assert BotUser.find(bot_user.id).linked?
    end

    test "unrecognized text falls back to instructions" do
      client = FakeClient.new
      handler = UpdateHandler.new(client: client, logger: Logger.new(nil))
      update = { "update_id" => 15, "message" => { "text" => "hello", "chat" => { "id" => 999 } } }

      handler.call(update)

      assert_match("Send /start to begin", client.messages.first[:text])
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

    def with_app_host(host)
      previous_host = ENV.fetch("APP_HOST", nil)
      ENV["APP_HOST"] = host
      yield
    ensure
      ENV["APP_HOST"] = previous_host
    end

  end
end
