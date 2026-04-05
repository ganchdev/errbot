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
#  index_events_on_notification_state  (notification_state)
#  index_events_on_project_id          (project_id)
#
# Foreign Keys
#
#  issue_id    (issue_id => issues.id)
#  project_id  (project_id => projects.id)
#
require "test_helper"

class EventTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
