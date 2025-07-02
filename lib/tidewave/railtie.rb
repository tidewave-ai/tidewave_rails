# frozen_string_literal: true

require "fast_mcp"
require "logger"
require "fileutils"
require "tidewave/configuration"
require "active_support/core_ext/class"

gem_tools_path = File.expand_path("tools/**/*.rb", __dir__)
Dir[gem_tools_path].each { |f| require f }

module Tidewave
  class Railtie < Rails::Railtie
    config.tidewave = Tidewave::Configuration.new(Rails.root.join("log", "tidewave.log"))

    initializer "tidewave.setup_mcp" do |app|
      # Prevent MCP server from being mounted if Rails is not running in development mode
      raise "For security reasons, Tidewave is only supported in development mode" unless Rails.env.development?

      config = app.config.tidewave

      # Set up MCP server with the host application
      FastMcp.mount_in_rails(
        app,
        name: "tidewave",
        version: Tidewave::VERSION,
        path_prefix: Tidewave::PATH_PREFIX,
        messages_route: Tidewave::MESSAGES_ROUTE,
        sse_route: Tidewave::SSE_ROUTE,
        logger: config.logger,
        allowed_origins: config.allowed_origins,
        localhost_only: config.localhost_only,
        allowed_ips: config.allowed_ips
      ) do |server|
        app.config.before_initialize do
          server.filter_tools do |request, tools|
            if request.params["include_fs_tools"] != "true"
              tools.reject { |tool| tool.tags.include?(:file_system_tool) }
            else
              tools
            end
          end

          server.register_tools(*Tidewave::Tools::Base.descendants)
        end
      end
    end
  end
end
