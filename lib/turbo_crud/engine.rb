# frozen_string_literal: true

# Rails Engine: lets the gem ship views/assets/helpers like a mini-app. 🧰
module TurboCrud
  class Engine < ::Rails::Engine
    isolate_namespace TurboCrud

    initializer "turbo_crud.helpers" do
      ActiveSupport.on_load(:action_view) do
        include TurboCrud::Helpers
      end
    end
  end
end
