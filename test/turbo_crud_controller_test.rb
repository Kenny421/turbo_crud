# frozen_string_literal: true

require_relative "test_helper"

class TurboCrudControllerTest < ActionDispatch::IntegrationTest
  # Turbo Streams use this content type.
  TURBO_STREAM = "text/vnd.turbo-stream.html"


  def assert_request_exception(klass, message_fragment = nil)
    exception = response.request.get_header("action_dispatch.exception")
    assert_kind_of klass, exception
    assert_includes exception.message, message_fragment if message_fragment
  end

  def test_create_renders_turbo_stream
    post "/posts", params: { title: "Hello", body: "World" }, headers: { "Accept" => TURBO_STREAM }
    assert_equal 200, response.status
    assert_includes response.media_type, "text/vnd.turbo-stream"
    assert_includes response.body, "turbo-stream"
    assert_includes response.body, "action=\"prepend\""
    assert_includes response.body, "target=\"posts_list\""
    assert_includes response.body, "created!"
  end

  def test_update_renders_turbo_stream
    p = Post.create!(title: "Old")
    patch "/posts/#{p.id}", params: { title: "New" }, headers: { "Accept" => TURBO_STREAM }
    assert_equal 200, response.status
    assert_includes response.body, "updated!"
  end

  def test_destroy_renders_turbo_stream
    p = Post.create!(title: "Bye")
    delete "/posts/#{p.id}", headers: { "Accept" => TURBO_STREAM }
    assert_equal 200, response.status
    assert_includes response.body, "deleted!"
  end

  def test_turbo_respond_create_requires_list
    post "/posts/without_list", params: { title: "Hello" }, headers: { "Accept" => TURBO_STREAM }
    assert_equal 500, response.status
    assert_request_exception(ArgumentError, "requires `list:`")
  end

  def test_turbo_create_rejects_invalid_insert
    post "/posts/invalid_insert", params: { title: "Hello" }, headers: { "Accept" => TURBO_STREAM }
    assert_equal 500, response.status
    assert_request_exception(ArgumentError, "Invalid `insert:`")
  end

  def test_turbo_update_rejects_invalid_replace
    post_record = Post.create!(title: "Old")

    patch "/posts/#{post_record.id}/invalid_replace", params: { title: "New" }, headers: { "Accept" => TURBO_STREAM }
    assert_equal 500, response.status
    assert_request_exception(ArgumentError, "Invalid `replace:`")
  end

  def test_missing_row_partial_has_clear_error
    post "/posts/bad_row_partial", params: { title: "Hello" }, headers: { "Accept" => TURBO_STREAM }
    assert_equal 500, response.status
    assert_request_exception(TurboCrud::MissingRowPartialError, "Could not find a row partial")
  end
end
