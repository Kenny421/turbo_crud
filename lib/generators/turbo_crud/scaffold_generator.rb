# frozen_string_literal: true

# Generator: makes files so you don't have to. 🧙‍♂️
#
# v0.4.3 upgrade:
# - `--install` wires up layout frames + CSS requires (best-effort + idempotent)
# - `--full` => also generates model+migration and injects routes
# - still supports: --container, --wrap-existing, --skip-model, --skip-routes
require "rails/generators"
require "rails/generators/named_base"

module TurboCrud
  module Generators
    class ScaffoldGenerator < Rails::Generators::NamedBase
      VALID_CONTAINERS = %w[modal drawer both].freeze

      source_root File.expand_path("templates", __dir__)

      # rails g turbo_crud:scaffold Post title body:text published:boolean --container=both --full --install
      argument :attributes, type: :array, default: [], banner: "field:type field:type"

      class_option :container,
                   type: :string,
                   default: "modal",
                   desc: "Choose where new/edit renders: modal, drawer, or both"

      class_option :wrap_existing,
                   type: :boolean,
                   default: false,
                   desc: "Skip generating views so you can keep existing forms/views"

      class_option :full,
                   type: :boolean,
                   default: false,
                   desc: "Also generate model+migration and inject resources routes"

      class_option :skip_model,
                   type: :boolean,
                   default: false,
                   desc: "Skip generating the model/migration (only with --full)"

      class_option :skip_routes,
                   type: :boolean,
                   default: false,
                   desc: "Skip injecting resources routes (only with --full)"

      class_option :migrate,
                   type: :boolean,
                   default: false,
                   desc: "Run db:migrate automatically when using --full (use --migrate to enable)"

      # NEW: installs layout frames + CSS requires.
      class_option :install,
                   type: :boolean,
                   default: false,
                   desc: "Wire up layout frames + CSS requires (best-effort, idempotent)"

      def validate_options!
        return if VALID_CONTAINERS.include?(normalized_container)

        raise Thor::Error,
              "Invalid --container=#{options[:container].inspect}. Expected one of: #{VALID_CONTAINERS.join(', ')}."
      end

      def generate_model_and_routes_if_full
        return unless options[:full]

        generate_model unless options[:skip_model]
        inject_routes unless options[:skip_routes]
        run_migrations_if_full
      end

      def create_controller
        template "controller.rb.tt", "app/controllers/#{plural_name}_controller.rb"
      end

      def create_views
        return if options[:wrap_existing]

        @generated_fields = build_fields_markup
        @generated_row_fields = build_row_fields_markup

        template "views/index.html.erb.tt", "app/views/#{plural_name}/index.html.erb"
        template "views/_row.html.erb.tt",  "app/views/#{plural_name}/_row.html.erb"
        template "views/_form.html.erb.tt", "app/views/#{plural_name}/_form.html.erb"

        case normalized_container
        when "modal"
          template "views/new.html.erb.tt",  "app/views/#{plural_name}/new.html.erb"
          template "views/edit.html.erb.tt", "app/views/#{plural_name}/edit.html.erb"
        when "drawer"
          template "views/new.drawer.html.erb.tt",  "app/views/#{plural_name}/new.html.erb"
          template "views/edit.drawer.html.erb.tt", "app/views/#{plural_name}/edit.html.erb"
        when "both"
          template "views/new.html.erb.tt",  "app/views/#{plural_name}/new.html.erb"
          template "views/edit.html.erb.tt", "app/views/#{plural_name}/edit.html.erb"
          template "views/new.drawer.html.erb.tt",  "app/views/#{plural_name}/new.drawer.html.erb"
          template "views/edit.drawer.html.erb.tt", "app/views/#{plural_name}/edit.drawer.html.erb"
        end
      end

      def install_if_requested
        return unless options[:install]

        install_layout_frames
        install_sprockets_css
      end

      private

      def normalized_container
        options[:container].to_s.strip.downcase
      end

      # -------------------------------------------
      # FULL MODE helpers (model + routes)
      # -------------------------------------------
      def generate_model
        if model_file_exists?
          generate_add_columns_migration
        else
          say_status :invoke, "rails g model #{class_name} ...", :green
          invoke "active_record:model", [class_name] + generator_attribute_args
        end
      end

      def inject_routes
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

        if routes_content.match?(/Rails\.application\.routes\.draw do\n/m)
          inject_into_file "config/routes.rb", "  #{route_line}\n", after: "Rails.application.routes.draw do\n"
          say_status :insert, "added #{route_line} to routes.rb", :green
        else
          append_to_file "config/routes.rb", "\n#{route_line}\n"
          say_status :append, "appended #{route_line} to routes.rb", :green
        end
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

      def run_migrations_if_full
        return if options[:skip_model]
        return unless options[:migrate]

        say_status :invoke, "bin/rails db:migrate", :green
        rails_command "db:migrate"
      end

      # -------------------------------------------
      # INSTALL MODE helpers (layout + CSS)
      # -------------------------------------------
      def install_layout_frames
        layout_path = File.join(destination_root, "app/views/layouts/application.html.erb")

        unless File.exist?(layout_path)
          say_status :warning, "layout not found: app/views/layouts/application.html.erb", :yellow
          say_status :info, "Add these near the end of <body>:", :blue
          say_status :info, "<%= turbo_crud_flash_frame %>\n<%= turbo_crud_modal_frame %>\n<%= turbo_crud_drawer_frame %>", :blue
          return
        end

        content = File.read(layout_path)

        frames = [
          "<%= turbo_crud_flash_frame %>",
          "<%= turbo_crud_modal_frame %>",
          "<%= turbo_crud_drawer_frame %>"
        ]

        # If already installed, do nothing.
        if frames.all? { |line| content.include?(line) }
          say_status :identical, "layout frames already installed", :blue
          return
        end

        insertion = "\n  " + frames.join("\n  ") + "\n"

        if content.include?("</body>")
          inject_into_file layout_path, insertion, before: "</body>"
          say_status :insert, "added TurboCrud frames to layout", :green
        else
          append_to_file layout_path, "\n#{frames.join("\n")}\n"
          say_status :append, "appended TurboCrud frames to layout (couldn't find </body>)", :green
        end
      end

      def install_sprockets_css
        css_path = File.join(destination_root, "app/assets/stylesheets/application.css")
        scss_path = File.join(destination_root, "app/assets/stylesheets/application.scss")

        target = File.exist?(css_path) ? css_path : (File.exist?(scss_path) ? scss_path : nil)

        unless target
          say_status :warning, "Could not find app/assets/stylesheets/application.css (or .scss).", :yellow
          say_status :info, "If you use Sprockets, add:", :blue
          say_status :info, " *= require turbo_crud\n *= require turbo_crud_modal\n *= require turbo_crud_drawer", :blue
          say_status :info, "If you use cssbundling, copy/import the gem CSS files into your pipeline.", :blue
          return
        end

        content = File.read(target)
        lines = [
          " *= require turbo_crud",
          " *= require turbo_crud_modal",
          " *= require turbo_crud_drawer"
        ]

        if lines.all? { |l| content.include?(l) }
          say_status :identical, "TurboCrud CSS already required", :blue
          return
        end

        if content.include?("*/")
          # Insert inside the Sprockets comment header.
          inject_into_file target, lines.map { |l| " #{l}\n" }.join, before: "*/"
          say_status :insert, "added TurboCrud requires to #{File.basename(target)}", :green
        else
          # Not a manifest-style file; append a helpful comment.
          append_to_file target, "\n/* TurboCrud: if you're using Sprockets manifest style, add requires:\n#{lines.join("\n")}\n*/\n"
          say_status :append, "appended TurboCrud CSS note to #{File.basename(target)}", :green
        end
      end

      # -------------------------------------------
      # Standard scaffold helper methods
      # -------------------------------------------
      def permitted_params
        attrs = attributes.map(&:name)
        return "" if attrs.empty?
        attrs.map { |a| ":#{a}" }.join(", ")
      end

      def build_fields_markup
        dynamic_fields_markup(
          preferred_attrs: attributes.map(&:name),
          preferred_types: attributes.each_with_object({}) do |attr, acc|
            acc[attr.name] = (attr.type || :string).to_s
          end
        )
      end

      def dynamic_fields_markup(preferred_attrs:, preferred_types:)
        preferred_literal = preferred_attrs.map { |name| "'#{name}'" }.join(", ")
        preferred_types_literal = preferred_types.map { |name, type| "'#{name}' => '#{type}'" }.join(", ")

        <<~ERB.chomp
          <% preferred_types = { #{preferred_types_literal} } %>
          <% model_attrs = f.object.class.attribute_names - %w[id created_at updated_at] %>
          <% preferred_attrs = [#{preferred_literal}] %>
          <% editable_attrs = if preferred_attrs.any?
                                preferred_attrs
                              else
                                model_attrs
                              end %>
          <% if editable_attrs.empty? %>
            <p class="rounded-xl border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-800">
              No editable columns found. Add model columns and run migrations, then reload this form.
            </p>
          <% else %>
            <% editable_attrs.each do |attr| %>
              <% attr_type = f.object.class.type_for_attribute(attr).type rescue :string %>
              <div>
                <%= f.label attr, class: "block text-sm font-semibold text-slate-900" %>
                <% field_type = (preferred_types[attr]&.to_sym || attr_type) %>
                <% if field_type == :boolean %>
                  <div class="mt-2 flex items-center gap-2">
                    <%= f.check_box attr, class: "h-4 w-4 rounded border-slate-300" %>
                    <span class="text-sm text-slate-700"><%= attr.humanize %></span>
                  </div>
                <% elsif field_type == :text %>
                  <%= f.text_area attr, rows: 5, class: "mt-1 w-full rounded-xl border border-slate-200 px-3 py-2" %>
                <% elsif [:integer, :float, :decimal].include?(field_type) %>
                  <%= f.number_field attr, class: "mt-1 w-full rounded-xl border border-slate-200 px-3 py-2" %>
                <% elsif field_type == :date %>
                  <%= f.date_field attr, class: "mt-1 w-full rounded-xl border border-slate-200 px-3 py-2" %>
                <% elsif [:datetime, :timestamp].include?(field_type) %>
                  <%= f.datetime_local_field attr, class: "mt-1 w-full rounded-xl border border-slate-200 px-3 py-2" %>
                <% elsif field_type == :time %>
                  <%= f.time_field attr, class: "mt-1 w-full rounded-xl border border-slate-200 px-3 py-2" %>
                <% else %>
                  <%= f.text_field attr, class: "mt-1 w-full rounded-xl border border-slate-200 px-3 py-2" %>
                <% end %>
              </div>
            <% end %>
          <% end %>
        ERB
      end

      def build_row_fields_markup
        preferred_literal = attributes.map(&:name).reject { |name| %w[id created_at updated_at].include?(name) }
                             .map { |name| "'#{name}'" }.join(", ")
        record_var = singular_name
        fallback_expr = row_label_expression

        <<~ERB.chomp
          <% preferred_attrs = [#{preferred_literal}] %>
          <% shown_any = false %>
          <% preferred_attrs.each do |attr| %>
            <% next unless #{record_var}.respond_to?(attr) %>
            <% raw_value = #{record_var}.public_send(attr) %>
            <% value =
              if raw_value == true || raw_value == false
                raw_value ? "Yes" : "No"
              elsif raw_value.present?
                raw_value
              end %>
            <% next if value.nil? %>
            <% shown_any = true %>
            <p class="mt-1 text-sm text-slate-600">
              <span class="font-semibold text-slate-700"><%= attr.humanize %>:</span>
              <%= value.is_a?(String) ? truncate(value, length: 120) : value %>
            </p>
          <% end %>
          <% unless shown_any %>
            <p class="text-sm font-semibold text-slate-900"><%= #{fallback_expr} %></p>
          <% end %>
        ERB
      end

      def row_label_expression
        preferred = %w[title name content body subject label description]
        available = attributes.map(&:name).reject { |name| %w[id created_at updated_at].include?(name) }
        runtime_content = "#{singular_name}.attributes.except('id', 'created_at', 'updated_at').values.find(&:present?)"
        fallback = '"' + class_name + '"'

        return "(#{runtime_content}) || #{fallback}" if available.empty?

        ordered = (preferred & available) + (available - preferred)
        checks = ordered.map do |attr|
          "(#{singular_name}.respond_to?(:#{attr}) && #{singular_name}.public_send(:#{attr}).presence)"
        end

        "#{checks.join(' || ')} || (#{runtime_content}) || #{fallback}"
      end

      def new_link_helper
        normalized_container == "drawer" ? "turbo_crud_drawer_link" : "turbo_crud_modal_link"
      end
    end
  end
end
