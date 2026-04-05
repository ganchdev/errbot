class CreateProjects < ActiveRecord::Migration[8.2]
  def change
    create_table :projects do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :ingest_token, null: false
      t.string :default_environment

      t.timestamps
    end
    add_index :projects, :slug, unique: true
    add_index :projects, :ingest_token, unique: true
  end
end
