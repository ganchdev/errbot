class AddUrlToProjects < ActiveRecord::Migration[8.2]
  def change
    add_column :projects, :url, :string
  end
end
