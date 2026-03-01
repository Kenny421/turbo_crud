# frozen_string_literal: true

# FullScaffoldGenerator:
# Think of this as "rails scaffold" + TurboCrud UI sugar. 🍬
#
# It will generate:
# - model + migration
# - routes (resources :plural)
# - TurboCrud controller + views (modal/drawer/both)
#
# It can run db:migrate automatically (opt-in via --migrate).
require "rails/generators"
require "rails/generators/named_base"

module TurboCrud
  module Generators
    class FullScaffoldGenerator < Rails::Generators::NamedBase
      VALID_CONTAINERS = %w[modal drawer both].freeze

      source_root File.expand_path("templates", __dir__)

      argument :attributes, type: :array, default: [], banner: "field:type field:type"

      class_option :container,
                   type: :string,
                   default: "modal",
                   desc: "Choose where new/edit renders: modal, drawer, or both"

      # If you already made the model, you can skip it.
      class_option :skip_model,
                   type: :boolean,
                   default: false,
                   desc: "Skip generating the model/migration"

      # If you already have routes, you can skip route injection.
      class_option :skip_routes,
                   type: :boolean,
                   default: false,
                   desc: "Skip injecting resources routes"

      class_option :migrate,
                   type: :boolean,
                   default: false,
                   desc: "Run db:migrate automatically after generating model/routes (use --migrate to enable)"

      def validate_options!
        normalized = options[:container].to_s.strip.downcase
        return if VALID_CONTAINERS.include?(normalized)

        raise Thor::Error,
              "Invalid --container=#{options[:container].inspect}. Expected one of: #{VALID_CONTAINERS.join(', ')}."
      end

      def generate_model
        return if options[:skip_model]

        if model_file_exists?
          generate_add_columns_migration
        else
          say_status :invoke, "rails g model #{class_name} #{generator_attribute_args.join(' ')}", :green
          # Invoke the Rails model generator.
          invoke "active_record:model", [class_name] + generator_attribute_args
        end
      end

      def inject_routes
        return if options[:skip_routes]

        route_line = "resources :#{plural_name}"
        routes_path = File.join(destination_root, "config/routes.rb")

        unless File.exist?(routes_path)
          say_status :warning, "config/routes.rb not found. Skipping routes injection.", :yellow
          return
        end

        routes_content = File.read(routes_path)

        if routes_content.include?(route_line)
          say_status :identical, "routes already include #{route_line}", :blue
          return
        end

        # Put routes near the top of the draw block.
        # If we can't find it, we just append at the end.
        if routes_content.match?(/Rails\.application\.routes\.draw do\n/m)
          inject_into_file "config/routes.rb", "  #{route_line}\n", after: "Rails.application.routes.draw do\n"
          say_status :insert, "added #{route_line} to routes.rb", :green
        else
          append_to_file "config/routes.rb", "\n#{route_line}\n"
          say_status :append, "appended #{route_line} to routes.rb", :green
        end
      end

      def generate_turbo_crud_scaffold
        say_status :invoke, "rails g turbo_crud:scaffold #{class_name} ...", :green

        # Invoke our own scaffold generator (the one that makes controller/views)
        invoke "turbo_crud:scaffold", [class_name] + attributes.map { |a| a.type ? "#{a.name}:#{a.type}" : a.name },
               container: options[:container]
      end

      def run_migrations
        return if options[:skip_model]
        return unless options[:migrate]

        say_status :invoke, "bin/rails db:migrate", :green
        rails_command "db:migrate"
      end

      def model_file_exists?
        File.exist?(File.join(destination_root, "app/models/#{file_name}.rb"))
      end

      def generate_add_columns_migration
        if attributes.empty?
          say_status :identical, "model exists and no attributes provided; skipping migration generation", :blue
          return
        end

        migration_suffix = attributes.map(&:name).join("_and_")
        migration_name = "add_#{migration_suffix}_to_#{plural_name}"

        say_status :invoke, "rails g migration #{migration_name} ...", :green
        invoke "active_record:migration", [migration_name] + generator_attribute_args
      end

      def generator_attribute_args
        attributes.map do |attr|
          type = (attr.type || :string).to_s
          "#{attr.name}:#{type}"
        end
      end
    end
  end
end
