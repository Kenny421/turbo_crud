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
      end

      def create_controller
        template "controller.rb.tt", "app/controllers/#{plural_name}_controller.rb"
      end

      def create_views
        return if options[:wrap_existing]

        @generated_fields = build_fields_markup

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
        say_status :invoke, "rails g model #{class_name} ...", :green
        invoke "active_record:model", [class_name], attributes: attributes
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
        return default_title_field if attributes.empty?

        attributes.map do |attr|
          name = attr.name
          type = (attr.type || :string).to_sym

          label = %Q(<%%= f.label :#{name}, class: "block text-sm font-semibold text-slate-900" %%>)
          input = case type
                  when :text
                    %Q(<%%= f.text_area :#{name}, rows: 5, class: "mt-1 w-full rounded-xl border border-slate-200 px-3 py-2" %%>)
                  when :boolean
                    %Q(<div class="mt-2 flex items-center gap-2"><%%= f.check_box :#{name}, class: "h-4 w-4 rounded border-slate-300" %%><span class="text-sm text-slate-700">#{name.to_s.tr("_", " ").capitalize}</span></div>)
                  when :integer, :float, :decimal
                    %Q(<%%= f.number_field :#{name}, class: "mt-1 w-full rounded-xl border border-slate-200 px-3 py-2" %%>)
                  when :date
                    %Q(<%%= f.date_field :#{name}, class: "mt-1 w-full rounded-xl border border-slate-200 px-3 py-2" %%>)
                  when :datetime, :timestamp
                    %Q(<%%= f.datetime_local_field :#{name}, class: "mt-1 w-full rounded-xl border border-slate-200 px-3 py-2" %%>)
                  when :time
                    %Q(<%%= f.time_field :#{name}, class: "mt-1 w-full rounded-xl border border-slate-200 px-3 py-2" %%>)
                  else
                    %Q(<%%= f.text_field :#{name}, class: "mt-1 w-full rounded-xl border border-slate-200 px-3 py-2" %%>)
                  end

          %Q(<div>
  #{label}
  #{input}
</div>)
        end.join("\n\n")
      end

      def default_title_field
        %Q(<div>
  <%%= f.label :title, class: "block text-sm font-semibold text-slate-900" %%>
  <%%= f.text_field :title, class: "mt-1 w-full rounded-xl border border-slate-200 px-3 py-2" %%>
</div>)
      end
    end
  end
end
