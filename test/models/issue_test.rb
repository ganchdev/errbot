# frozen_string_literal: true

# == Schema Information
#
# Table name: issues
#
#  id                :integer          not null, primary key
#  culprit           :string
#  fingerprint_hash  :string           not null
#  first_seen_at     :datetime
#  last_environment  :string
#  last_release      :string
#  last_seen_at      :datetime
#  level             :string
#  occurrences_count :integer          default(0)
#  platform          :string
#  status            :string           default("open"), not null
#  title             :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  project_id        :integer          not null
#
# Indexes
#
#  index_issues_on_fingerprint_hash                 (fingerprint_hash)
#  index_issues_on_project_id                       (project_id)
#  index_issues_on_project_id_and_fingerprint_hash  (project_id,fingerprint_hash) UNIQUE
#  index_issues_on_status                           (status)
#
# Foreign Keys
#
#  project_id  (project_id => projects.id)
#
require "test_helper"

class IssueTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
