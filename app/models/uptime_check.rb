# frozen_string_literal: true

# == Schema Information
#
# Table name: uptime_checks
#
#  id               :integer          not null, primary key
#  checked_at       :datetime         not null
#  response_code    :integer
#  response_time_ms :integer
#  ssl_error        :string
#  ssl_expires_at   :datetime
#  ssl_status       :string           default("not_applicable"), not null
#  status           :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  project_id       :integer          not null
#
# Indexes
#
#  index_uptime_checks_on_project_id             (project_id)
#  index_uptime_checks_on_project_id_and_checked_at  (project_id,checked_at)
#
# Foreign Keys
#
#  project_id  (project_id => projects.id)
#
class UptimeCheck < ApplicationRecord

  belongs_to :project
  has_many :telegram_messages, as: :source, dependent: :destroy

  STATUSES = %w[up down].freeze
  SSL_STATUSES = %w[not_applicable valid expiring_soon expired error].freeze
  SSL_ALERT_STATUSES = %w[expiring_soon expired].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :ssl_status, inclusion: { in: SSL_STATUSES }
  validates :checked_at, presence: true

  # Returns whether this check's SSL state should trigger an alert.
  #
  # @return [Boolean]
  def ssl_alert?
    SSL_ALERT_STATUSES.include?(ssl_status)
  end

  # Returns whether SSL metadata applies to this check's URL scheme.
  #
  # @return [Boolean]
  def ssl_applicable?
    ssl_status != "not_applicable"
  end

end
