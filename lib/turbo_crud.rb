# frozen_string_literal: true

# Front door of the gem. Knock knock. 🚪
require "rails"
require "action_view"
require "turbo-rails"

require_relative "turbo_crud/version"
require_relative "turbo_crud/engine"
require_relative "turbo_crud/controller"
require_relative "turbo_crud/helpers"

module TurboCrud
  class Error < StandardError; end
  class MissingRowPartialError < Error; end

  # Config stays small to stay sane. 🧘‍♂️
  class Configuration
    attr_accessor :modal_frame_id, :drawer_frame_id, :flash_frame_id,
                  :default_insert, :default_container, :row_partial, :model_defaults

    def initialize
      # Where modal content gets swapped in.
      @modal_frame_id = "turbo_modal"

      # Where drawer content gets swapped in.
      @drawer_frame_id = "turbo_drawer"

      # Where flash/toast content gets swapped in.
      @flash_frame_id = "turbo_flash"

      # When creating, where does the new row go? :prepend or :append
      @default_insert = :prepend

      # Which container should forms target by default?
      # :modal or :drawer
      @default_container = :modal

      # Which partial should be used to render a row when replacing/inserting?
      # :auto => try <collection>/row, then <collection>/<element>
      # Or set a string like "posts/post" or "shared/post_row".
      @row_partial = :auto

      # Per-model overrides:
      # {
      #   "Blog" => { row_partial: "blogs/blog", container: :drawer, insert: :append }
      # }
      @model_defaults = {}
    end
  end

  def self.config
    @config ||= Configuration.new
  end

  def self.configure
    yield(config)
  end

  # Resolve model-specific defaults by trying common key styles.
  def self.model_default_for(model_or_record, key)
    defaults = model_defaults_for(model_or_record)
    return nil unless defaults.is_a?(Hash)

    defaults[key.to_sym]
  end

  def self.model_defaults_for(model_or_record)
    klass =
      if model_or_record.is_a?(Class)
        model_or_record
      elsif model_or_record.respond_to?(:klass) && model_or_record.klass.is_a?(Class)
        model_or_record.klass
      elsif model_or_record.respond_to?(:class)
        model_or_record.class
      end

    return nil unless klass&.respond_to?(:model_name)

    keys = [
      klass,
      klass.name,
      klass.name.to_sym,
      klass.model_name.name,
      klass.model_name.name.to_sym,
      klass.model_name.element,
      klass.model_name.element.to_sym,
      klass.model_name.singular,
      klass.model_name.singular.to_sym
    ]

    keys.each do |candidate|
      value = config.model_defaults[candidate]
      return value if value
    end

    nil
  end
end
