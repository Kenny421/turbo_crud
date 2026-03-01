# frozen_string_literal: true

class AddFieldsToComments < ActiveRecord::Migration[8.1]
  def change
    add_column :comments, :title, :string, null: false, default: ""
    add_column :comments, :body, :text
    add_column :comments, :published, :boolean, null: false, default: false
  end
end
