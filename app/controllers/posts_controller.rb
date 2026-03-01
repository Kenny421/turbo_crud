# frozen_string_literal: true

# frozen_string_literal: true

class PostsController < ApplicationController
  include TurboCrud::Controller

  def index
    @posts = Post.order(created_at: :desc)
  end

  def new
    @post = Post.new
  end

  def edit
    @post = Post.find(params[:id])
  end

  def create
    @post = Post.new(post_params)

    # ✨ turbo_respond = create/update responder with all TurboCrud features:
    # - create: inserts into list
    # - flash: updates turbo flash frame
    # - close: clears BOTH modal + drawer frames (whichever is open)
    # - html fallback: redirects like normal
    turbo_respond(@post, list: Post, success_message: "Post created!")
  end

  def update
    @post = Post.find(params[:id])
    @post.assign_attributes(post_params)

    # ✨ replaces the row (dom_id(@post)) by default
    turbo_respond(@post, list: Post, success_message: "Post updated!")
  end

  def destroy
    @post = Post.find(params[:id])

    # 💥 removes the row + shows flash
    turbo_destroy(@post, list: Post, success_message: "Post deleted.")
  end

  private

  def post_params
    params.require(:post).permit(:title, :body)
  end
end
