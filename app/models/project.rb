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
class Project < ApplicationRecord

  has_many :issues, dependent: :destroy
  has_many :events, dependent: :destroy
  has_many :uptime_checks, dependent: :destroy

  scope :with_url, -> { where.not(url: [nil, ""]) }

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :ingest_token, presence: true, uniqueness: true

  before_validation :generate_ingest_token, on: :create

  private

  def generate_ingest_token
    self.ingest_token ||= SecureRandom.hex(32)
  end

end
