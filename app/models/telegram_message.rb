# frozen_string_literal: true

# == Schema Information
#
# Table name: telegram_messages
#
#  id           :integer          not null, primary key
#  message_type :string           not null
#  sent_at      :datetime
#  source_id    :integer          not null
#  source_type  :string           not null
#  status       :string           default("pending"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_telegram_messages_on_source_and_message_type  (source_type,source_id,message_type) UNIQUE
#  index_telegram_messages_on_status                   (status)
#
class TelegramMessage < ApplicationRecord

  MESSAGE_TYPES = %w[new_issue reappeared_issue project_down].freeze
  STATUSES = %w[pending sent skipped failed].freeze

  belongs_to :source, polymorphic: true

  validates :message_type, inclusion: { in: MESSAGE_TYPES }, uniqueness: { scope: %i[source_type source_id] }
  validates :status, inclusion: { in: STATUSES }

  def self.enqueue_for!(source:, message_type:)
    telegram_message = find_or_create_by!(source: source, message_type: message_type) do |message|
      message.status = "pending"
    end

    NotifyTelegramJob.perform_later(telegram_message.id) if telegram_message.previously_new_record?

    telegram_message
  rescue ActiveRecord::RecordNotUnique
    find_by!(source: source, message_type: message_type)
  end

end
