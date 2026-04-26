# frozen_string_literal: true

class CreateTelegramMessages < ActiveRecord::Migration[8.2]

  def change
    create_table :telegram_messages do |t|
      t.string :source_type, null: false
      t.integer :source_id, null: false
      t.string :message_type, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :sent_at

      t.timestamps
    end

    add_index :telegram_messages, :status
    add_index :telegram_messages, %i[source_type source_id message_type], unique: true, name: "index_telegram_messages_on_source_and_message_type"
  end

end
