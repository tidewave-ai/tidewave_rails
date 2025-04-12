# frozen_string_literal: true

module Tidewave
  class Engine < ::Rails::Engine
    isolate_namespace Tidewave

    # Add app/tools to the paths so we can store precoded tools there
    config.paths.add "app/tools", eager_load: true
  end
end
