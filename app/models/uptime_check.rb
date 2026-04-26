# frozen_string_literal: true

# == Schema Information
#
# Table name: uptime_checks
#
#  id               :integer          not null, primary key
#  checked_at       :datetime         not null
#  response_code    :integer
#  response_time_ms :integer
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

  validates :status, inclusion: { in: STATUSES }
  validates :checked_at, presence: true

end
