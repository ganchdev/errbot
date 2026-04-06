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
#
# Indexes
#
#  index_bot_users_on_authorized_user_id  (authorized_user_id)
#  index_bot_users_on_chat_id_and_code    (chat_id,code)
#  index_bot_users_on_api_token           (api_token) UNIQUE
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

  test "generates api_token on creation" do
    bot_user = BotUser.create!(authorized_user: @authorized_user, chat_id: "123456")
    assert bot_user.api_token.present?
    assert bot_user.api_token.length == 32
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

  test "find_by_token returns bot_user if valid" do
    bot_user = BotUser.create!(authorized_user: @authorized_user, chat_id: "123456")
    found = BotUser.find_by(api_token: bot_user.api_token)
    assert_equal bot_user.id, found.id
  end

  test "find_by_token returns nil if token not found" do
    BotUser.create!(authorized_user: @authorized_user, chat_id: "123456")
    found = BotUser.find_by(api_token: "nonexistent_token")
    assert_nil found
  end

end
