class AddTitleToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :title, :string
  end
end
