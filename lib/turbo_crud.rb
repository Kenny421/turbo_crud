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
    attr_accessor :modal_frame_id, :drawer_frame_id, :flash_frame_id, :default_insert, :default_container, :row_partial

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
    end
  end

  def self.config
    @config ||= Configuration.new
  end

  def self.configure
    yield(config)
  end
end
