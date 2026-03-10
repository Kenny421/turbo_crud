# frozen_string_literal: true

require "rails/generators"
require_relative "concerns/install_support"

module TurboCrud
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include InstallSupport

      class_option :stimulus,
                   type: :boolean,
                   default: false,
                   desc: "Also install an optional TurboCrud Stimulus controller"

      def install
        say_status :check, "Installing TurboCrud layout/CSS wiring", :blue
        install_layout_frames
        install_sprockets_css

        return unless options[:stimulus]

        say_status :check, "Installing optional TurboCrud Stimulus controller", :blue
        install_stimulus_controller
      end
    end
  end
end
