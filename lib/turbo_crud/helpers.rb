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
      turbo_frame_tag(TurboCrud.config.modal_frame_id)
    end

    # Drawer frame: like a modal, but it slides in from the side. 🧊➡️
    def turbo_crud_drawer_frame
      turbo_frame_tag(TurboCrud.config.drawer_frame_id)
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
    def turbo_crud_default_frame_id
      TurboCrud.config.default_container.to_sym == :drawer ? TurboCrud.config.drawer_frame_id : TurboCrud.config.modal_frame_id
    end

    # Wrapper around form_with that targets the correct turbo frame.
    def turbo_crud_form_with(*args, frame: turbo_crud_default_frame_id, **kwargs, &block)
      kwargs[:data] ||= {}
      kwargs[:data][:turbo_frame] ||= frame
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
def turbo_crud_container(title:, container: nil, close_to_top: true, &block)
  # Capture the block output (the form / content you already have).
  body = capture(&block)

  chosen = (container || TurboCrud.config.default_container).to_sym

  # We render a partial shipped by the gem, because HTML is nicer to read there.
  partial =
    case chosen
    when :drawer then "turbo_crud/shared/container_drawer"
    else "turbo_crud/shared/container_modal"
    end

  render partial, title: title, body: body, close_to_top: close_to_top
end

  end
end
