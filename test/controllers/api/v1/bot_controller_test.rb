# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    class BotControllerTest < ActionDispatch::IntegrationTest

      test "verify confirms a pending bot link and returns an api token" do
        authorized_user = authorized_users(:one)
        bot_user = BotUser.begin_verification!(chat_id: "123456", authorized_user: authorized_user)

        post "/api/v1/bot/verify", params: { code: bot_user.code, chat_id: "123456" }

        assert_response :success

        bot_user.reload
        assert bot_user.linked?

        body = JSON.parse(response.body)
        assert_equal true, body["success"]
        assert_equal authorized_user.email_address, body.dig("user", "email")
        assert_equal bot_user.api_token, body["token"]
      end

      test "verify rejects an invalid code" do
        authorized_user = authorized_users(:one)
        BotUser.begin_verification!(chat_id: "123456", authorized_user: authorized_user)

        post "/api/v1/bot/verify", params: { code: "000000", chat_id: "123456" }

        assert_response :unauthorized
      end

    end
  end
end
