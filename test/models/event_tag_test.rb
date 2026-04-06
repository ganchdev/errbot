# frozen_string_literal: true

# == Schema Information
#
# Table name: event_tags
#
#  id         :integer          not null, primary key
#  key        :string
#  value      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  event_id   :integer          not null
#
# Indexes
#
#  index_event_tags_on_event_id  (event_id)
#
# Foreign Keys
#
#  event_id  (event_id => events.id)
#
require "test_helper"

class EventTagTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
