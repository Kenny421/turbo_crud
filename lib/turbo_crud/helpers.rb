# frozen_string_literal: true

module TurboCrud
  module Helpers
    # Example: turbo_list_id(Post) => "posts_list"
    def turbo_list_id(klass_or_relation)
      klass = klass_or_relation.respond_to?(:klass) ? klass_or_relation.klass : klass_or_relation
      "#{klass.model_name.plural}_list"
    end

    # Example: turbo_row_id(@post) => "post_123"
    def turbo_row_id(record)
      dom_id(record)
    end

    # Flash frame: Turbo Streams can replace this for instant feedback.
    def turbo_crud_flash_frame
      turbo_frame_tag(TurboCrud.config.flash_frame_id) do
        render "turbo_crud/shared/flash"
      end
    end

    # Modal frame: new/edit pages can render inside here.
    def turbo_crud_modal_frame
      safe_join([
        turbo_frame_tag(TurboCrud.config.modal_frame_id),
        turbo_crud_behavior_script_once
      ])
    end

    # Drawer frame: like a modal, but it slides in from the side. 🧊➡️
    def turbo_crud_drawer_frame
      safe_join([
        turbo_frame_tag(TurboCrud.config.drawer_frame_id),
        turbo_crud_behavior_script_once
      ])
    end

    # Modal link: opens URL inside modal frame.
    def turbo_crud_modal_link(text, url, **options)
      options[:data] ||= {}
      options[:data][:turbo_frame] = TurboCrud.config.modal_frame_id
      options[:class] ||= "turbo-crud__modal-link"
      link_to(text, url, **options)
    end

    # Drawer link: opens URL inside drawer frame.
    def turbo_crud_drawer_link(text, url, **options)
      options[:data] ||= {}
      options[:data][:turbo_frame] = TurboCrud.config.drawer_frame_id
      options[:class] ||= "turbo-crud__drawer-link"
      link_to(text, url, **options)
    end

    # Decide the default container frame for forms based on configuration.
    # If you set `default_container = :drawer`, forms will target the drawer.
    def turbo_crud_default_frame_id(model_or_record = nil)
      # Prefer the frame requested by the current Turbo visit so drawer/modal
      # links and form targets stay aligned in existing apps.
      requested = turbo_crud_requested_frame_id
      return requested if [TurboCrud.config.modal_frame_id, TurboCrud.config.drawer_frame_id].include?(requested)

      container = turbo_crud_default_container_for(model_or_record)
      container == :drawer ? TurboCrud.config.drawer_frame_id : TurboCrud.config.modal_frame_id
    end

    # Wrapper around form_with that targets the correct turbo frame.
    def turbo_crud_form_with(*args, frame: nil, **kwargs, &block)
      model_for_defaults = turbo_crud_model_from_form_args(args, kwargs)
      resolved_frame = frame || turbo_crud_default_frame_id(model_for_defaults)

      kwargs[:data] ||= {}
      kwargs[:data][:turbo_frame] ||= resolved_frame
      # Auto-disable submit controls while request is in flight (opt out by passing
      # data: { turbo_crud_auto_disable: false } on a specific form).
      kwargs[:data][:turbo_crud_auto_disable] = true unless kwargs[:data].key?(:turbo_crud_auto_disable)
      form_with(*args, **kwargs, &block)
    end
    # Wrap any existing view inside a TurboCrud container (modal or drawer).
    #
    # Usage (in your existing new/edit):
    #   <%= turbo_crud_container title: "New Post" do %>
    #     <%= render "form" %>
    #   <% end %>
    #
    # The container defaults to TurboCrud.config.default_container (:modal or :drawer),
    # but you can force one:
    #   turbo_crud_container(title: "...", container: :drawer) { ... }
    def turbo_crud_container(title:, container: nil, model: nil, close_to_top: true, &block)
      # Capture the block output (the form / content you already have).
      body = capture(&block)

      chosen =
        if container
          container.to_sym
        else
          # Auto-select container from the incoming Turbo frame request.
          case turbo_crud_requested_frame_id
          when TurboCrud.config.drawer_frame_id then :drawer
          when TurboCrud.config.modal_frame_id then :modal
          else
            turbo_crud_default_container_for(model)
          end
        end

      # We render a partial shipped by the gem, because HTML is nicer to read there.
      partial =
        case chosen
        when :drawer then "turbo_crud/shared/container_drawer"
        else "turbo_crud/shared/container_modal"
        end

      frame_id = chosen == :drawer ? TurboCrud.config.drawer_frame_id : TurboCrud.config.modal_frame_id

      turbo_frame_tag(frame_id) do
        render partial, title: title, body: body, close_to_top: close_to_top
      end
    end

    private

    def turbo_crud_requested_frame_id
      # Support both Rails helper API and raw headers so this works across
      # Rails versions and different request shapes.
      helper_frame_id = turbo_frame_request_id if respond_to?(:turbo_frame_request_id, true)
      helper_frame_id || request.headers["Turbo-Frame"] || request.get_header("HTTP_TURBO_FRAME") || params[:turbo_frame]
    end

    def turbo_crud_default_container_for(model_or_record = nil)
      per_model = TurboCrud.model_default_for(model_or_record, :container)&.to_sym
      return per_model if %i[modal drawer].include?(per_model)

      TurboCrud.config.default_container.to_sym
    end

    def turbo_crud_model_from_form_args(args, kwargs)
      candidate = kwargs[:model]
      if candidate.nil? && args.first.is_a?(Hash)
        candidate = args.first[:model]
      end

      if candidate.respond_to?(:to_model)
        candidate = candidate.to_model
      end

      candidate
    end

    def turbo_crud_behavior_script_once
      return "".html_safe if defined?(@turbo_crud_behavior_script_rendered) && @turbo_crud_behavior_script_rendered

      @turbo_crud_behavior_script_rendered = true
      javascript_tag(<<~JS)
        (() => {
          if (window.__turboCrudBehaviorInstalled) return;
          window.__turboCrudBehaviorInstalled = true;

          const modalId = "#{TurboCrud.config.modal_frame_id}";
          const drawerId = "#{TurboCrud.config.drawer_frame_id}";
          const managedFrameIds = new Set([modalId, drawerId]);

          function openContainer() {
            for (const id of managedFrameIds) {
              const frame = document.getElementById(id);
              if (!frame) continue;
              if (!frame.innerHTML || frame.innerHTML.trim() === "") continue;
              const container = frame.querySelector("[data-turbo-crud-container]");
              if (container) return container;
            }
            return null;
          }

          function focusables(container) {
            const selector = [
              "a[href]",
              "button:not([disabled])",
              "input:not([disabled]):not([type='hidden'])",
              "select:not([disabled])",
              "textarea:not([disabled])",
              "[tabindex]:not([tabindex='-1'])"
            ].join(",");
            return Array.from(container.querySelectorAll(selector)).filter((el) => {
              return !el.hasAttribute("disabled") && (el.offsetParent !== null || el === document.activeElement);
            });
          }

          // Focus modal/drawer content when Turbo swaps a frame response in.
          document.addEventListener("turbo:frame-load", (event) => {
            const frame = event.target;
            if (!frame || !managedFrameIds.has(frame.id)) return;
            const container = frame.querySelector("[data-turbo-crud-container]");
            if (!container) return;
            const autofocus = container.querySelector("[autofocus]") || focusables(container)[0] || container;
            if (autofocus && typeof autofocus.focus === "function") autofocus.focus();
          });

          // Escape closes active container; Tab is trapped inside active container.
          document.addEventListener("keydown", (event) => {
            const container = openContainer();
            if (!container) return;

            if (event.key === "Escape") {
              const closeButton = container.querySelector("[data-turbo-crud-close], .turbo-crud__modal-close, .turbo-crud__drawer-close");
              if (closeButton) {
                event.preventDefault();
                closeButton.click();
              }
              return;
            }

            if (event.key !== "Tab") return;
            const nodes = focusables(container);
            if (nodes.length === 0) return;

            const first = nodes[0];
            const last = nodes[nodes.length - 1];
            const active = document.activeElement;

            if (event.shiftKey && active === first) {
              event.preventDefault();
              last.focus();
            } else if (!event.shiftKey && active === last) {
              event.preventDefault();
              first.focus();
            }
          });

          // Disable submit buttons while Turbo form request is in flight.
          document.addEventListener("submit", (event) => {
            const form = event.target;
            if (!(form instanceof HTMLFormElement)) return;
            if (String(form.dataset.turboCrudAutoDisable) === "false") return;

            const submits = form.querySelectorAll("button[type='submit'], input[type='submit']");
            if (!submits.length) return;

            form.dataset.turboCrudLoading = "true";
            submits.forEach((btn) => {
              btn.disabled = true;
              if (btn.tagName === "BUTTON") {
                if (!btn.dataset.turboCrudOriginalText) btn.dataset.turboCrudOriginalText = btn.textContent || "";
                if (btn.dataset.turboCrudLoadingText) btn.textContent = btn.dataset.turboCrudLoadingText;
              } else if (btn.tagName === "INPUT") {
                if (!btn.dataset.turboCrudOriginalText) btn.dataset.turboCrudOriginalText = btn.value || "";
                if (btn.dataset.turboCrudLoadingText) btn.value = btn.dataset.turboCrudLoadingText;
              }
            });
          });

          // Re-enable submits after Turbo finishes request cycle.
          document.addEventListener("turbo:submit-end", (event) => {
            const form = event.target;
            if (!(form instanceof HTMLFormElement)) return;

            const submits = form.querySelectorAll("button[type='submit'], input[type='submit']");
            submits.forEach((btn) => {
              btn.disabled = false;
              if (btn.tagName === "BUTTON" && btn.dataset.turboCrudOriginalText) {
                btn.textContent = btn.dataset.turboCrudOriginalText;
              } else if (btn.tagName === "INPUT" && btn.dataset.turboCrudOriginalText) {
                btn.value = btn.dataset.turboCrudOriginalText;
              }
            });
            delete form.dataset.turboCrudLoading;
          });
        })();
      JS
    end

  end
end
