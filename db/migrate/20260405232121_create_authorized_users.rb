class CreateAuthorizedUsers < ActiveRecord::Migration[8.2]
  def change
    create_table :authorized_users do |t|
      t.string :email_address
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :authorized_users, :email_address, unique: true
  end
end
