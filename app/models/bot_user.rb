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
class BotUser < ApplicationRecord

  belongs_to :authorized_user

  before_validation :generate_code, on: :create
  before_validation :generate_token, on: :create

  def self.fetch_by_code_and_chat_id!(code, chat_id)
    bot_user = find_by(chat_id: chat_id, code: code)
    return nil unless bot_user

    if bot_user.expires_at > Time.current
      bot_user
    else
      bot_user.destroy

      nil
    end
  end

  private

  def generate_code
    self.code = SecureRandom.random_number(100_000).to_s.rjust(6, "0")
    self.expires_at = 10.minutes.from_now
  end

  def generate_token
    self.api_token ||= SecureRandom.alphanumeric(32)
  end

end
