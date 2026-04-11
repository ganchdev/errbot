# frozen_string_literal: true

class AddLinkedAtToBotUsers < ActiveRecord::Migration[8.2]

  def change
    add_column :bot_users, :linked_at, :datetime
    add_index :bot_users, :linked_at
  end

end
