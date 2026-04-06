class CreateBotUsers < ActiveRecord::Migration[8.2]

  def change
    create_table :bot_users do |t|
      t.references :authorized_user, null: false, foreign_key: true
      t.string :code, null: false
      t.datetime :expires_at, null: false
      t.string :api_token
      t.string :chat_id, null: false

      t.timestamps
    end

    add_index :bot_users, :api_token, unique: true
    add_index :bot_users, [:chat_id, :code]
  end

end
