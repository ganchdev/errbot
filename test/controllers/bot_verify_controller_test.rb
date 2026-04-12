# frozen_string_literal: true

require "test_helper"

class BotVerifyControllerTest < ActionDispatch::IntegrationTest

  test "show creates a pending verification code for the signed in matching user" do
    authorized_user = authorized_users(:one)
    user = authorized_user.user
    sign_in_as(user)

    get bot_verify_path, params: { chat_id: "123456", email: authorized_user.email_address }

    assert_response :success
    assert_match "Verify Telegram Account", response.body

    bot_user = BotUser.find_by(chat_id: "123456")
    assert_equal authorized_user, bot_user.authorized_user
    assert_not bot_user.linked?
    assert_match bot_user.code, response.body
  end

  test "show rejects a signed in user whose email does not match" do
    sign_in_as(users(:two))

    get bot_verify_path, params: { chat_id: "123456", email: authorized_users(:one).email_address }

    assert_response :success
    assert_match "Signed-in Google account does not match the requested email", response.body
    assert_nil BotUser.find_by(chat_id: "123456")
  end
end
