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
  has_many :telegram_messages, as: :source, dependent: :destroy

  validates :notification_reason, inclusion: { in: NOTIFICATION_REASONS }, allow_nil: true
  validates :notification_state, inclusion: { in: NOTIFICATION_STATES }

  scope :pending_notification, -> { where(notification_state: "pending") }

  def parsed_payload
    @parsed_payload ||= JSON.parse(raw_json.presence || "{}")
  rescue JSON::ParserError
    Ingestion::EnvelopeParser.call(raw_json.presence || "")
  rescue Ingestion::InvalidPayloadError
    {}
  end

  def stack_frames
    exception = parsed_payload.dig("exception", "values")&.last || parsed_payload["exception"] || {}
    Array(exception.dig("stacktrace", "frames")).grep(Hash)
  end

  def exception_summary
    exception_message.to_s.lines.first.to_s.strip.presence || exception_type
  end

  def exception_details
    exception_message.to_s.lines.drop(1).join.rstrip.presence
  end

  def preferred_stack_frames
    stack_frames.reverse
  end

end
