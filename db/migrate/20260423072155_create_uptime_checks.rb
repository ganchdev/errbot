class CreateUptimeChecks < ActiveRecord::Migration[8.2]
  def change
    create_table :uptime_checks do |t|
      t.references :project, null: false, foreign_key: true
      t.string :status, null: false
      t.datetime :checked_at, null: false
      t.integer :response_code
      t.integer :response_time_ms

      t.timestamps
    end

    add_index :uptime_checks, [:project_id, :checked_at]
  end
end
