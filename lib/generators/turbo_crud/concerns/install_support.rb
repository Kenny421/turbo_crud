# frozen_string_literal: true

module TurboCrud
  module Generators
    module InstallSupport
      private

      def install_layout_frames
        layout_path = File.join(destination_root, "app/views/layouts/application.html.erb")

        unless File.exist?(layout_path)
          say_status :warning, "layout not found: app/views/layouts/application.html.erb", :yellow
          say_status :info, "Add these near the end of <body>:", :blue
          say_status :info, "<%= turbo_crud_flash_frame %>\n<%= turbo_crud_modal_frame %>\n<%= turbo_crud_drawer_frame %>", :blue
          return false
        end

        content = File.read(layout_path)

        frames = [
          "<%= turbo_crud_flash_frame %>",
          "<%= turbo_crud_modal_frame %>",
          "<%= turbo_crud_drawer_frame %>"
        ]

        return true if frames.all? { |line| content.include?(line) }

        insertion = "\n  " + frames.join("\n  ") + "\n"

        if content.include?("</body>")
          inject_into_file layout_path, insertion, before: "</body>"
        else
          append_to_file layout_path, "\n#{frames.join("\n")}\n"
        end

        true
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
          return false
        end

        content = File.read(target)
        sprockets_lines = [
          " *= require turbo_crud",
          " *= require turbo_crud_modal",
          " *= require turbo_crud_drawer"
        ]
        import_lines = [
          "@import \"turbo_crud.css\";",
          "@import \"turbo_crud_modal.css\";",
          "@import \"turbo_crud_drawer.css\";"
        ]

        return true if sprockets_lines.all? { |line| content.include?(line) }
        return true if import_lines.all? { |line| content.include?(line) }

        if content.include?("/*") && content.include?("*/") && content.include?("*= require")
          inject_into_file target, sprockets_lines.map { |line| " #{line}\n" }.join, before: "*/"
        else
          append_to_file target, "\n/* TurboCrud imports (Propshaft/cssbundling/plain CSS): */\n#{import_lines.join("\n")}\n"
        end

        true
      end

      def install_stimulus_controller
        controllers_index = File.join(destination_root, "app/javascript/controllers/index.js")
        application_js = File.join(destination_root, "app/javascript/application.js")
        controller_path = File.join(destination_root, "app/javascript/controllers/turbo_crud_controller.js")
        flash_controller_path = File.join(destination_root, "app/javascript/controllers/turbo_crud_flash_controller.js")

        unless File.exist?(controllers_index) || File.exist?(application_js)
          say_status :warning, "No JS entrypoint found for Stimulus (expected app/javascript/controllers/index.js or app/javascript/application.js)", :yellow
          return false
        end

        empty_directory "app/javascript/controllers"

        create_file controller_path, <<~JS unless File.exist?(controller_path)
          import { Controller } from "@hotwired/stimulus"

          // Optional TurboCrud behavior if your app prefers Stimulus over inline script hooks.
          export default class extends Controller {
            connect() {
              this.onKeydown = this.onKeydown.bind(this)
              document.addEventListener("keydown", this.onKeydown)
            }

            disconnect() {
              document.removeEventListener("keydown", this.onKeydown)
            }

            onKeydown(event) {
              if (event.key !== "Escape") return

              const container = document.querySelector("[data-turbo-crud-container]")
              if (!container) return

              const closeButton = container.querySelector("[data-turbo-crud-close], .turbo-crud__modal-close, .turbo-crud__drawer-close")
              if (!closeButton) return

              event.preventDefault()
              closeButton.click()
            }
          }
        JS

        create_file flash_controller_path, <<~JS unless File.exist?(flash_controller_path)
          import { Controller } from "@hotwired/stimulus"

          // Handles flash dismiss + optional auto-hide.
          export default class extends Controller {
            static values = { autoHideMs: Number }

            connect() {
              this.scheduleAutoHide()
            }

            dismiss(event) {
              const flash = event.target.closest(".turbo-crud__flash")
              if (!flash) return
              flash.remove()
            }

            scheduleAutoHide() {
              if (!this.hasAutoHideMsValue || this.autoHideMsValue <= 0) return

              this.clearTimer()
              this.timer = window.setTimeout(() => {
                this.element.innerHTML = ""
              }, this.autoHideMsValue)
            }

            disconnect() {
              this.clearTimer()
            }

            clearTimer() {
              if (!this.timer) return
              window.clearTimeout(this.timer)
              this.timer = null
            }
          }
        JS

        import_line = "import TurboCrudController from \"./turbo_crud_controller\"\n"
        register_line = "application.register(\"turbo-crud\", TurboCrudController)\n"
        flash_import_line = "import TurboCrudFlashController from \"./turbo_crud_flash_controller\"\n"
        flash_register_line = "application.register(\"turbo-crud-flash\", TurboCrudFlashController)\n"

        if File.exist?(controllers_index)
          index_content = File.read(controllers_index)
          append_to_file controllers_index, "\n#{import_line}" unless index_content.include?("./turbo_crud_controller")
          append_to_file controllers_index, flash_import_line unless index_content.include?("./turbo_crud_flash_controller")

          refreshed_content = File.read(controllers_index)
          append_to_file controllers_index, register_line unless refreshed_content.include?("application.register(\"turbo-crud\"")
          append_to_file controllers_index, flash_register_line unless refreshed_content.include?("application.register(\"turbo-crud-flash\"")
          return true
        end

        app_content = File.read(application_js)
        if app_content.include?("@hotwired/stimulus")
          unless app_content.include?("./controllers/turbo_crud_controller")
            append_to_file application_js, "\n// TurboCrud Stimulus controllers\n#{import_line}#{flash_import_line}"
          end
          return true
        end

        say_status :warning, "Stimulus is not initialized in app/javascript/application.js. Install @hotwired/stimulus first.", :yellow
        false
      end
    end
  end
end
