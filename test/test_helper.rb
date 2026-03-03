# frozen_string_literal: true

# Test helper: loads a tiny Rails app so we can run engine/controller tests.
ENV["RAILS_ENV"] ||= "test"

require "bundler/setup"
require "rails"
require "action_controller/railtie"
require "active_record"
require "minitest/autorun"
require "turbo_crud"

# Minimal in-memory Rails application for tests. (Small but mighty.)
class DummyApp < Rails::Application
  config.secret_key_base = "test" * 8
  config.eager_load = false
  config.logger = Logger.new(nil)
  config.hosts << "www.example.com"
end

DummyApp.initialize!
ActionController::Base.prepend_view_path File.expand_path("views", __dir__)

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

# Quick schema for tests (no migrations needed).
ActiveRecord::Schema.define do
  create_table :posts, force: true do |t|
    t.string :title
    t.text :body
    t.timestamps
  end
end

class Post < ActiveRecord::Base
  validates :title, presence: true
end

class PostsController < ActionController::Base
  include TurboCrud::Controller

  def new
    @post = Post.new
    render(**turbo_crud_template_for(:new))
  end

  def edit
    @post = Post.find(params[:id])
    render(**turbo_crud_template_for(:edit))
  end

  def create
    @post = Post.new(title: params[:title], body: params[:body])
    turbo_respond(@post, list: Post, row_partial: "turbo_crud/shared/flash", success_message: "created!")
  end

  def update
    @post = Post.find(params[:id])
    @post.assign_attributes(title: params[:title])
    turbo_respond(@post, list: Post, row_partial: "turbo_crud/shared/flash", success_message: "updated!")
  end

  def destroy
    @post = Post.find(params[:id])
    turbo_destroy(@post, list: Post, success_message: "deleted!")
  end

  def create_without_list
    @post = Post.new(title: params[:title], body: params[:body])
    turbo_respond(@post, success_message: "created!")
  end

  def create_invalid_insert
    @post = Post.new(title: params[:title], body: params[:body])
    turbo_create(@post, list: Post, insert: :middle, success_message: "created!")
  end

  def update_invalid_replace
    @post = Post.find(params[:id])
    @post.assign_attributes(title: params[:title] || "New")
    turbo_update(@post, replace: { invalid: true }, success_message: "updated!")
  end

  def create_bad_row_partial
    @post = Post.new(title: params[:title], body: params[:body])
    turbo_create(@post, list: Post, row_partial: "posts/does_not_exist", success_message: "created!")
  end

  def create_with_auto_row_partial
    @post = Post.new(title: params[:title], body: params[:body])
    turbo_create(@post, list: Post, success_message: "created!")
  end
end

DummyApp.routes.draw do
  resources :posts, only: [:new, :edit, :create, :update, :destroy]
  post "/posts/without_list", to: "posts#create_without_list"
  post "/posts/invalid_insert", to: "posts#create_invalid_insert"
  patch "/posts/:id/invalid_replace", to: "posts#update_invalid_replace"
  post "/posts/bad_row_partial", to: "posts#create_bad_row_partial"
  post "/posts/auto_row_partial", to: "posts#create_with_auto_row_partial"
end
