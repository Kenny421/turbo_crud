# frozen_string_literal: true

require "rails/generators"

module TurboCrud
  module Generators
    class DoctorGenerator < Rails::Generators::Base
      class_option :strict,
                   type: :boolean,
                   default: false,
                   desc: "Exit with an error when issues are found"

      def run_checks
        @issues = 0

        # Keep output actionable and grouped so users can fix issues quickly. can be re-run after fixes to confirm. 
        say_status :check, "TurboCrud doctor", :blue
        check_layout_frames
        check_controller_includes
        check_view_partials
        print_summary
      end

      private
        # Each check method should call ok! or issue! to report results and increment issue count as needed.
      def check_layout_frames
        layout_path = File.join(destination_root, "app/views/layouts/application.html.erb")
        return issue!("Missing layout file: app/views/layouts/application.html.erb") unless File.exist?(layout_path)

        content = File.read(layout_path)
        required = [
          "turbo_crud_flash_frame",
          "turbo_crud_modal_frame",
          "turbo_crud_drawer_frame"
        ]

        missing = required.reject { |entry| content.include?(entry) }
        if missing.empty?
          ok!("Layout includes TurboCrud frames")
        else
          issue!("Layout is missing: #{missing.join(', ')}")
        end
      end
        # Check that at least one controller includes the TurboCrud::Controller module, which is necessary for the helper methods and stream rendering to work. This is a common oversight when integrating.
      def check_controller_includes
        controller_files = Dir[File.join(destination_root, "app/controllers/**/*_controller.rb")]
        return issue!("No controllers found under app/controllers") if controller_files.empty?

        any_include = controller_files.any? do |path|
          File.read(path).include?("include TurboCrud::Controller")
        end

        if any_include
          ok!("At least one controller includes TurboCrud::Controller")
        else
          issue!("No controller includes TurboCrud::Controller")
        end
      end
# Check for the presence of view partials that follow the expected naming conventions for turbo stream rendering (e.g., _row.html.erb for rows, or model-specific partials). This helps ensure that the necessary view components are in place for TurboCrud to function properly.
      def check_view_partials
        partials = Dir[File.join(destination_root, "app/views/**/_*.html.erb")]
        if partials.empty?
          issue!("No view partials found (expected row/model partials for turbo stream rendering)")
          return
        end

        row_like = partials.any? { |path| path.end_with?("/_row.html.erb") }
        model_like = partials.any? { |path| File.basename(path) != "_row.html.erb" }

        if row_like || model_like
          ok!("View partials found for stream rendering")
        else
          issue!("No usable stream partials found")
        end
      end
# After running all checks, print a summary of results. If issues were found and --strict is enabled, raise an error to fail CI builds. Otherwise, provide a warning with guidance on how to fail in CI if desired.
      def print_summary
        if @issues.zero?
          say_status :ok, "TurboCrud doctor passed (0 issues)", :green
          return
        end

        message = "TurboCrud doctor found #{@issues} issue(s)"
        if options[:strict]
          # Useful for CI: fail fast when app integration is incomplete.
          raise Thor::Error, message
        else
          say_status :warning, "#{message}. Re-run with --strict to fail in CI.", :yellow
        end
      end

      def ok!(message)
        say_status :ok, message, :green
      end

      def issue!(message)
        @issues += 1
        say_status :missing, message, :yellow
      end
    end
  end
end
