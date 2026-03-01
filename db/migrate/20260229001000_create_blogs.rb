# frozen_string_literal: true

class CreateBlogs < ActiveRecord::Migration[8.1]
  def change
    create_table :blogs do |t|
      t.string :title, null: false
      t.text :body
      t.boolean :published, null: false, default: false

      t.timestamps
    end
  end
end
