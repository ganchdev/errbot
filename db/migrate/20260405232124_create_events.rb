class CreateEvents < ActiveRecord::Migration[8.2]
  def change
    create_table :events do |t|
      t.references :project, null: false, foreign_key: true
      t.references :issue, null: false, foreign_key: true
      t.string :event_uuid
      t.datetime :occurred_at
      t.string :environment
      t.string :release
      t.string :server_name
      t.string :transaction_name
      t.string :exception_type
      t.string :exception_message
      t.boolean :handled
      t.string :level
      t.text :raw_json
      t.string :notification_state, default: "pending"
      t.datetime :notified_at

      t.timestamps
    end
    add_index :events, :event_uuid
    add_index :events, :notification_state
  end
end
