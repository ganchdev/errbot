class CreateUsers < ActiveRecord::Migration[8.2]
  def change
    create_table :users do |t|
      t.string :email_address
      t.string :name
      t.string :first_name
      t.string :last_name
      t.string :image
      t.boolean :admin

      t.timestamps
    end
  end
end
