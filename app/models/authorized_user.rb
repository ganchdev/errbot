# frozen_string_literal: true

# == Schema Information
#
# Table name: authorized_users
#
#  id            :integer          not null, primary key
#  email_address :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_id       :integer
#
# Indexes
#
#  index_authorized_users_on_email_address  (email_address) UNIQUE
#  index_authorized_users_on_user_id        (user_id)
#
# Foreign Keys
#
#  user_id  (user_id => users.id)
#
class AuthorizedUser < ApplicationRecord

  belongs_to :user, optional: true

  validates :email_address, presence: true, uniqueness: true

end
