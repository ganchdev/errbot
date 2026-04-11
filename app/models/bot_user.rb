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
class BotUser < ApplicationRecord

  belongs_to :authorized_user

  before_validation :generate_code, on: :create

  scope :linked, -> { where.not(linked_at: nil) }
  scope :pending, -> { where(linked_at: nil) }

  # Looks up a pending bot user by chat and verification code, deleting it if expired.
  #
  # @param code [String]
  # @param chat_id [String]
  # @return [BotUser, nil]
  def self.fetch_by_code_and_chat_id!(code, chat_id)
    bot_user = pending.find_by(chat_id: chat_id, code: code)
    return nil unless bot_user

    if bot_user.expires_at > Time.current
      bot_user
    else
      bot_user.destroy

      nil
    end
  end

  # Starts or restarts the verification flow for a Telegram chat.
  #
  # @param chat_id [String]
  # @param authorized_user [AuthorizedUser]
  # @return [BotUser]
  def self.begin_verification!(chat_id:, authorized_user:)
    bot_user = find_or_initialize_by(chat_id: chat_id.to_s)
    bot_user.authorized_user = authorized_user
    bot_user.linked_at = nil
    bot_user.refresh_code!
    bot_user.save!
    bot_user
  end

  # Confirms a pending verification code and marks the Telegram chat as linked.
  #
  # @param code [String]
  # @param chat_id [String]
  # @return [BotUser, nil]
  def self.confirm_link!(code:, chat_id:)
    bot_user = fetch_by_code_and_chat_id!(code.to_s, chat_id.to_s)
    return nil unless bot_user

    bot_user.complete_link!
  end

  # Finds a linked bot user for a Telegram chat id.
  #
  # @param chat_id [String]
  # @return [BotUser, nil]
  def self.find_linked_by_chat_id(chat_id)
    linked.find_by(chat_id: chat_id.to_s)
  end

  # Returns whether this bot user has completed Telegram account linking.
  #
  # @return [Boolean]
  def linked?
    linked_at.present?
  end

  # Marks this bot user as linked and issues a fresh API token.
  #
  # @return [BotUser]
  def complete_link!
    update!(
      linked_at: Time.current,
      api_token: SecureRandom.alphanumeric(32)
    )

    self
  end

  # Refreshes the one-time verification code and expiration window.
  #
  # @return [void]
  def refresh_code!
    self.code = SecureRandom.random_number(100_000).to_s.rjust(6, "0")
    self.expires_at = 10.minutes.from_now
  end

  private

  def generate_code
    refresh_code!
  end

end
