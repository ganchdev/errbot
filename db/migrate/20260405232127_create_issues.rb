class CreateIssues < ActiveRecord::Migration[8.2]
  def change
    create_table :issues do |t|
      t.references :project, null: false, foreign_key: true
      t.string :fingerprint_hash, null: false
      t.string :title
      t.string :culprit
      t.string :status, null: false, default: "open"
      t.string :level
      t.string :platform
      t.datetime :first_seen_at
      t.datetime :last_seen_at
      t.integer :occurrences_count, default: 0
      t.string :last_release
      t.string :last_environment

      t.timestamps
    end
    add_index :issues, :fingerprint_hash
    add_index :issues, :status
    add_index :issues, [ :project_id, :fingerprint_hash ], unique: true
  end
end
