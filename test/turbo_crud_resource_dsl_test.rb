# frozen_string_literal: true

require_relative "test_helper"

class TurboCrudResourceDslTest < ActionDispatch::IntegrationTest
  TURBO_STREAM = "text/vnd.turbo-stream.html"

  def assert_request_exception(klass, message_fragment = nil)
    exception = response.request.get_header("action_dispatch.exception")
    assert_kind_of klass, exception
    assert_includes exception.message, message_fragment if message_fragment
  end

  def setup
    super
    PunditResourcePostsController.authorization_calls = []
    CancanResourcePostsController.authorization_calls = []
    AutoPunditPostsController.authorization_calls = []
    AutoCancanPostsController.authorization_calls = []
    AutoBothAuthPostsController.authorization_calls = []
    AutoDisabledAuthPostsController.authorization_calls = []
  end

  def test_index_uses_scope_ordering
    Post.create!(title: "Older", created_at: 2.days.ago, updated_at: 2.days.ago)
    Post.create!(title: "Newest", created_at: Time.now, updated_at: Time.now)

    get "/resource_posts"
    assert_equal 200, response.status

    newer_pos = response.body.index("Newest")
    older_pos = response.body.index("Older")
    assert newer_pos, "expected response to include Newest"
    assert older_pos, "expected response to include Older"
    assert_operator newer_pos, :<, older_pos
  end

  def test_container_setting_applies_model_default
    assert_equal :drawer, TurboCrud.model_default_for(Post, :container)
  end

  def test_create_uses_permitted_attributes_only
    post "/resource_posts",
         params: { post: { title: "Hello", body: "Blocked" } },
         headers: { "Accept" => TURBO_STREAM }

    assert_equal 200, response.status
    created = Post.order(:id).last
    assert_equal "Hello", created.title
    assert_nil created.body
    assert_includes response.body, "action=\"prepend\""
    assert_includes response.body, "target=\"posts_list\""
  end

  def test_update_uses_permitted_attributes_only
    post_record = Post.create!(title: "Before", body: "Body")

    patch "/resource_posts/#{post_record.id}",
          params: { post: { title: "After", body: "Blocked" } },
          headers: { "Accept" => TURBO_STREAM }

    assert_equal 200, response.status
    post_record.reload
    assert_equal "After", post_record.title
    assert_equal "Body", post_record.body
  end

  def test_pundit_authorizer_is_invoked
    post "/pundit_resource_posts",
         params: { post: { title: "Auth" } },
         headers: { "Accept" => TURBO_STREAM }

    assert_equal 200, response.status
    assert_includes PunditResourcePostsController.authorization_calls, "create:Post"
  end

  def test_cancancan_authorizer_is_invoked
    post_record = Post.create!(title: "Delete")

    delete "/cancan_resource_posts/#{post_record.id}", headers: { "Accept" => TURBO_STREAM }

    assert_equal 200, response.status
    assert_includes CancanResourcePostsController.authorization_calls, "destroy:Post"
  end

  def test_missing_pundit_authorizer_raises_clear_error
    get "/missing_pundit_posts"
    assert_equal 500, response.status
    assert_request_exception(NotImplementedError, "include Pundit::Authorization")
  end

  def test_missing_cancancan_authorizer_raises_clear_error
    get "/missing_cancan_posts"
    assert_equal 500, response.status
    assert_request_exception(NotImplementedError, "include CanCan::ControllerAdditions")
  end

  def test_rejects_invalid_authorizer_configuration
    error = assert_raises(ArgumentError) do
      Class.new(ActionController::Base) do
        include TurboCrud::Controller
        turbo_crud_resource Post, permit: %i[title], authorize_with: :invalid
      end
    end

    assert_includes error.message, "Invalid `authorize_with:`"
  end

  def test_rejects_empty_permit_configuration
    error = assert_raises(ArgumentError) do
      Class.new(ActionController::Base) do
        include TurboCrud::Controller
        turbo_crud_resource Post, permit: []
      end
    end

    assert_includes error.message, "requires `permit:`"
  end

  def test_auto_detects_pundit_when_authorize_exists
    post "/auto_pundit_posts",
         params: { post: { title: "Auto Pundit" } },
         headers: { "Accept" => TURBO_STREAM }

    assert_equal 200, response.status
    assert_includes AutoPunditPostsController.authorization_calls, "create:Post"
  end

  def test_auto_detects_cancancan_when_authorize_bang_exists
    post_record = Post.create!(title: "Auto CanCan")

    delete "/auto_cancan_posts/#{post_record.id}", headers: { "Accept" => TURBO_STREAM }

    assert_equal 200, response.status
    assert_includes AutoCancanPostsController.authorization_calls, "destroy:Post"
  end

  def test_auto_detection_prefers_cancancan_when_both_methods_exist
    post_record = Post.create!(title: "Both")

    delete "/auto_both_auth_posts/#{post_record.id}", headers: { "Accept" => TURBO_STREAM }

    assert_equal 200, response.status
    assert_includes AutoBothAuthPostsController.authorization_calls, "cancan:destroy:Post"
    refute_includes AutoBothAuthPostsController.authorization_calls, "pundit:Post"
  end

  def test_explicit_nil_disables_auto_detection
    post_record = Post.create!(title: "No Auth")

    delete "/auto_disabled_auth_posts/#{post_record.id}", headers: { "Accept" => TURBO_STREAM }

    assert_equal 200, response.status
    assert_equal [], AutoDisabledAuthPostsController.authorization_calls
  end
end
