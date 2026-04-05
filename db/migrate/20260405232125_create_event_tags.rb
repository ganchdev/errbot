class CreateEventTags < ActiveRecord::Migration[8.2]
  def change
    create_table :event_tags do |t|
      t.references :event, null: false, foreign_key: true
      t.string :key
      t.string :value

      t.timestamps
    end
  end
end
