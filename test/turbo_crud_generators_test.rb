# frozen_string_literal: true

require_relative "test_helper"
require "rails/generators/test_case"
require "fileutils"

require_relative "../lib/generators/turbo_crud/scaffold_generator"
require_relative "../lib/generators/turbo_crud/full_scaffold_generator"

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
