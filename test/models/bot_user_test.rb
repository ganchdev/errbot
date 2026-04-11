# frozen_string_literal: true

# == Schema Information
#
# Table name: bot_users
#
#  id                 :integer          not null, primary key
#  code               :string           not null
#  expires_at         :datetime         not null
#  api_token          :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  authorized_user_id :integer          not null
#  chat_id            :string           not null
#  linked_at          :datetime
#
# Indexes
#
#  index_bot_users_on_authorized_user_id  (authorized_user_id)
#  index_bot_users_on_chat_id_and_code    (chat_id,code)
#  index_bot_users_on_api_token           (api_token) UNIQUE
#  index_bot_users_on_linked_at           (linked_at)
#
# Foreign Keys
#
#  authorized_user_id  (authorized_user_id => authorized_users.id)
#
require "test_helper"

class BotUserTest < ActiveSupport::TestCase

  setup do
    @authorized_user = authorized_users(:one)
  end

  test "generates code on creation" do
    bot_user = BotUser.create!(authorized_user: @authorized_user, chat_id: "123456")
    assert bot_user.code.present?
    assert bot_user.code.length == 6
  end

  test "does not generate api_token on creation" do
    bot_user = BotUser.create!(authorized_user: @authorized_user, chat_id: "123456")
    assert_nil bot_user.api_token
  end

  test "sets expires_at on creation" do
    bot_user = BotUser.create!(authorized_user: @authorized_user, chat_id: "123456")
    assert bot_user.expires_at.present?
    assert bot_user.expires_at > Time.current
  end

  test "find_by_code_and_chat_id returns bot_user if valid" do
    bot_user = BotUser.create!(authorized_user: @authorized_user, chat_id: "123456")
    found = BotUser.fetch_by_code_and_chat_id!(bot_user.code, "123456")
    assert_equal bot_user.id, found.id
  end

  test "find_by_code_and_chat_id returns nil if code wrong" do
    BotUser.create!(authorized_user: @authorized_user, chat_id: "123456")
    found = BotUser.fetch_by_code_and_chat_id!("000000", "123456")
    assert_nil found
  end

  test "find_by_code_and_chat_id returns nil if expired" do
    bot_user = BotUser.create!(authorized_user: @authorized_user, chat_id: "123456")
    bot_user.update!(expires_at: 1.hour.ago)
    found = BotUser.fetch_by_code_and_chat_id!(bot_user.code, "123456")
    assert_nil found
  end

  test "begin_verification refreshes code and resets linked_at" do
    bot_user = BotUser.create!(
      authorized_user: @authorized_user,
      chat_id: "123456",
      linked_at: Time.current,
      api_token: "old_token"
    )
    old_code = bot_user.code

    refreshed = BotUser.begin_verification!(chat_id: "123456", authorized_user: @authorized_user)

    assert_equal bot_user.id, refreshed.id
    assert_nil refreshed.linked_at
    assert_not_equal old_code, refreshed.code
  end

  test "confirm_link marks bot_user as linked and issues a token" do
    bot_user = BotUser.begin_verification!(chat_id: "123456", authorized_user: @authorized_user)

    linked_bot_user = BotUser.confirm_link!(chat_id: "123456", code: bot_user.code)

    assert linked_bot_user.linked?
    assert linked_bot_user.api_token.present?
  end

  test "find_by_token returns bot_user if valid" do
    bot_user = BotUser.create!(authorized_user: @authorized_user, chat_id: "123456")
    bot_user.complete_link!
    found = BotUser.linked.find_by(api_token: bot_user.api_token)
    assert_equal bot_user.id, found.id
  end

  test "find_by_token returns nil if token not found" do
    BotUser.create!(authorized_user: @authorized_user, chat_id: "123456")
    found = BotUser.linked.find_by(api_token: "nonexistent_token")
    assert_nil found
  end

end
