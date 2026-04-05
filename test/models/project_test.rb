# frozen_string_literal: true

# == Schema Information
#
# Table name: projects
#
#  id                  :integer          not null, primary key
#  default_environment :string
#  ingest_token        :string           not null
#  name                :string           not null
#  slug                :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_projects_on_ingest_token  (ingest_token) UNIQUE
#  index_projects_on_slug          (slug) UNIQUE
#
require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
