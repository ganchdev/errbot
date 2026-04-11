# frozen_string_literal: true

class AddNotificationReasonToEvents < ActiveRecord::Migration[8.2]

  def change
    add_column :events, :notification_reason, :string
    add_index :events, :notification_reason
  end

end
