# frozen_string_literal: true

require "logger"
require "fileutils"
require "tidewave/configuration"
require "tidewave/middleware"

gem_tools_path = File.expand_path("tools/**/*.rb", __dir__)
Dir[gem_tools_path].each { |f| require f }

module Tidewave
  class Railtie < Rails::Railtie
    config.tidewave = Tidewave::Configuration.new()

    initializer "tidewave.setup" do |app|
      unless app.config.enable_reloading
        raise "For security reasons, Tidewave is only supported in environments where config.enable_reloading is true (typically development)"
      end

      app.config.middleware.insert_after(
        ActionDispatch::Callbacks,
        Tidewave::Middleware,
        app.config.tidewave
      )
    end
  end
end
