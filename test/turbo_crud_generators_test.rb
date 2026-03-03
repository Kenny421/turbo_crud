# frozen_string_literal: true

require_relative "test_helper"
require "rails/generators/test_case"
require "fileutils"

require_relative "../lib/generators/turbo_crud/scaffold_generator"
require_relative "../lib/generators/turbo_crud/full_scaffold_generator"
require_relative "../lib/generators/turbo_crud/doctor_generator"

class TurboCrudScaffoldGeneratorTest < Rails::Generators::TestCase
  tests TurboCrud::Generators::ScaffoldGenerator
  destination File.expand_path("tmp/scaffold_generator", __dir__)
  setup :prepare_destination

  def setup
    super
    FileUtils.mkdir_p(File.join(destination_root, "config"))
    File.write(File.join(destination_root, "config/routes.rb"), "Rails.application.routes.draw do\nend\n")

    FileUtils.mkdir_p(File.join(destination_root, "app/views/layouts"))
    File.write(File.join(destination_root, "app/views/layouts/application.html.erb"), "<html><body>\n</body></html>\n")

    FileUtils.mkdir_p(File.join(destination_root, "app/assets/stylesheets"))
    File.write(File.join(destination_root, "app/assets/stylesheets/application.css"), "/*\n *= require_tree .\n */\n")
  end

  def test_rejects_invalid_container_option
    run_generator ["Post", "title:string", "--container=sidepanel"]
    assert_no_file "app/controllers/posts_controller.rb"
  end

  def test_install_is_idempotent
    run_generator ["Post", "title:string", "--install"]
    first_layout = File.read(File.join(destination_root, "app/views/layouts/application.html.erb"))
    first_css = File.read(File.join(destination_root, "app/assets/stylesheets/application.css"))

    run_generator ["Post", "title:string", "--install"]
    second_layout = File.read(File.join(destination_root, "app/views/layouts/application.html.erb"))
    second_css = File.read(File.join(destination_root, "app/assets/stylesheets/application.css"))

    assert_equal first_layout, second_layout
    assert_equal first_css, second_css
  end

  def test_no_attributes_does_not_generate_title_field
    run_generator ["Van"]
    assert_file "app/views/vans/_form.html.erb"
    assert_file "app/views/vans/_row.html.erb"
    assert_file "app/controllers/vans_controller.rb"
    form = File.read(File.join(destination_root, "app/views/vans/_form.html.erb"))
    row = File.read(File.join(destination_root, "app/views/vans/_row.html.erb"))
    controller = File.read(File.join(destination_root, "app/controllers/vans_controller.rb"))
    refute_includes form, "f.label :title"
    refute_includes form, "f.text_field :title"
    assert_includes form, "editable_attrs = if preferred_attrs.any?"
    assert_includes form, "model_attrs = f.object.class.attribute_names - %w[id created_at updated_at]"
    assert_includes form, "No editable columns found. Add model columns and run migrations"
    assert_includes row, "attributes.except('id', 'created_at', 'updated_at').values.find(&:present?)"
    refute_includes row, '##{van.id}'
    assert_includes controller, "safe_van_attrs"
    assert_includes controller, "Van.attribute_names"
  end

  def test_row_prefers_title_over_other_fields
    run_generator ["Post", "content:text", "title:string"]
    row = File.read(File.join(destination_root, "app/views/posts/_row.html.erb"))
    assert_includes row, "preferred_attrs = ['content', 'title']"
    assert_includes row, "next unless post.respond_to?(attr)"
    assert_includes row, "post.public_send(attr)"
  end

  def test_drawer_container_uses_drawer_new_link
    run_generator ["Note", "body:text", "--container=drawer"]
    index = File.read(File.join(destination_root, "app/views/notes/index.html.erb"))
    assert_includes index, "turbo_crud_drawer_link"
    refute_includes index, "turbo_crud_modal_link"
  end

  def test_modal_container_new_view_uses_modal_frame
    run_generator ["Thing", "name:string", "--container=modal"]
    new_view = File.read(File.join(destination_root, "app/views/things/new.html.erb"))
    assert_includes new_view, "turbo_frame_tag TurboCrud.config.modal_frame_id"
  end

  def test_drawer_container_new_view_uses_drawer_frame
    run_generator ["Thing", "name:string", "--container=drawer"]
    new_view = File.read(File.join(destination_root, "app/views/things/new.html.erb"))
    assert_includes new_view, "turbo_frame_tag TurboCrud.config.drawer_frame_id"
  end

  def test_generated_controller_renders_frame_variant_for_new_and_edit
    run_generator ["Post", "title:string"]
    controller = File.read(File.join(destination_root, "app/controllers/posts_controller.rb"))

    assert_includes controller, "render(**turbo_crud_template_for(:new))"
    assert_includes controller, "render(**turbo_crud_template_for(:edit))"
  end

  def test_full_mode_passes_declared_attributes_to_model_generator
    generator = TurboCrud::Generators::ScaffoldGenerator.new(
      ["Dog", "title", "body:text", "published:boolean"],
      { "full" => true },
      destination_root: destination_root
    )
    captured = []

    generator.define_singleton_method(:invoke) do |name, args = [], *_rest, **_kwargs|
      captured << [name, args]
    end
    generator.send(:generate_model)

    call = captured.find { |name, _args| name == "active_record:model" }
    assert call, "expected active_record:model to be invoked"
    _name, args = call
    assert_equal ["Dog", "title:string", "body:text", "published:boolean"], args
  end
end

class TurboCrudFullScaffoldGeneratorTest < Rails::Generators::TestCase
  tests TurboCrud::Generators::FullScaffoldGenerator
  destination File.expand_path("tmp/full_scaffold_generator", __dir__)
  setup :prepare_destination

  def setup
    super
    FileUtils.mkdir_p(File.join(destination_root, "config"))
    File.write(File.join(destination_root, "config/routes.rb"), "Rails.application.routes.draw do\nend\n")
  end

  def test_rejects_invalid_container_option
    run_generator ["Post", "title:string", "--container=sidepanel", "--skip-model"]
    assert_no_file "app/controllers/posts_controller.rb"
  end

  def test_generates_scaffold_with_skip_options
    run_generator ["Post", "title:string", "--skip-model", "--skip-routes", "--container=drawer"]

    assert_file "app/controllers/posts_controller.rb"
    assert_file "app/views/posts/new.html.erb"
    assert_file "app/views/posts/edit.html.erb"
    assert_no_file "app/models/post.rb"

    routes = File.read(File.join(destination_root, "config/routes.rb"))
    refute_includes routes, "resources :posts"
  end
end

class TurboCrudDoctorGeneratorTest < Rails::Generators::TestCase
  tests TurboCrud::Generators::DoctorGenerator
  destination File.expand_path("tmp/doctor_generator", __dir__)
  setup :prepare_destination

  def test_reports_missing_configuration
    generator = TurboCrud::Generators::DoctorGenerator.new([], {}, destination_root: destination_root)
    output, = capture_io { generator.run_checks }
    assert_includes output, "Missing layout file"
    assert_includes output, "No controllers found"
    assert_includes output, "No view partials found"
    assert_includes output, "found 3 issue(s)"
  end

  def test_passes_when_core_setup_exists
    FileUtils.mkdir_p(File.join(destination_root, "app/views/layouts"))
    File.write(
      File.join(destination_root, "app/views/layouts/application.html.erb"),
      "<%= turbo_crud_flash_frame %>\n<%= turbo_crud_modal_frame %>\n<%= turbo_crud_drawer_frame %>\n"
    )

    FileUtils.mkdir_p(File.join(destination_root, "app/controllers"))
    File.write(
      File.join(destination_root, "app/controllers/blogs_controller.rb"),
      "class BlogsController < ApplicationController\n  include TurboCrud::Controller\nend\n"
    )

    FileUtils.mkdir_p(File.join(destination_root, "app/views/blogs"))
    File.write(
      File.join(destination_root, "app/views/blogs/_blog.html.erb"),
      "<div id=\"<%= dom_id(blog) %>\"><%= blog.title %></div>\n"
    )

    generator = TurboCrud::Generators::DoctorGenerator.new([], {}, destination_root: destination_root)
    output, = capture_io { generator.run_checks }
    assert_includes output, "doctor passed (0 issues)"
  end

  def test_strict_mode_raises_when_issues_exist
    generator = TurboCrud::Generators::DoctorGenerator.new([], { "strict" => true }, destination_root: destination_root)
    error = assert_raises(Thor::Error) { generator.run_checks }
    assert_includes error.message, "TurboCrud doctor found 3 issue(s)"
  end
end
