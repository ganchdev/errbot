# frozen_string_literal: true

# == Schema Information
#
# Table name: events
#
#  id                 :integer          not null, primary key
#  environment        :string
#  event_uuid         :string
#  exception_message  :string
#  exception_type     :string
#  handled            :boolean
#  level              :string
#  notification_reason :string
#  notification_state :string           default("pending")
#  notified_at        :datetime
#  occurred_at        :datetime
#  raw_json           :text
#  release            :string
#  server_name        :string
#  transaction_name   :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  issue_id           :integer          not null
#  project_id         :integer          not null
#
# Indexes
#
#  index_events_on_event_uuid          (event_uuid)
#  index_events_on_issue_id            (issue_id)
#  index_events_on_notification_reason  (notification_reason)
#  index_events_on_notification_state  (notification_state)
#  index_events_on_project_id          (project_id)
#
# Foreign Keys
#
#  issue_id    (issue_id => issues.id)
#  project_id  (project_id => projects.id)
#
class Event < ApplicationRecord

  # Reasons an event is eligible for outbound notification delivery.
  NOTIFICATION_REASONS = %w[new_issue reappeared].freeze
  # Delivery lifecycle states for Telegram notifications.
  NOTIFICATION_STATES = %w[pending sent skipped failed].freeze

  belongs_to :project
  belongs_to :issue
  has_many :event_tags, dependent: :destroy

  validates :notification_reason, inclusion: { in: NOTIFICATION_REASONS }, allow_nil: true
  validates :notification_state, inclusion: { in: NOTIFICATION_STATES }

  scope :pending_notification, -> { where(notification_state: "pending") }

end
