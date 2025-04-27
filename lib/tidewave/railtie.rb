# frozen_string_literal: true

require "fast_mcp"
require "logger"
require "fileutils"
require "tidewave/tool_resolver"

module Tidewave
  class Railtie < Rails::Railtie
    initializer "tidewave.setup_mcp" do |app|
      # Prevent MCP server from being mounted if Rails is not running in development mode
      raise "For security reasons, Tidewave is only supported in development mode" unless Rails.env.development?

      # Set up MCP server with the host application
      FastMcp.mount_in_rails(
        app,
        name: "tidewave",
        version: Tidewave::VERSION,
        path_prefix: Tidewave::PATH_PREFIX,
        messages_route: Tidewave::MESSAGES_ROUTE,
        sse_route: Tidewave::SSE_ROUTE,
        logger: Logger.new(STDOUT)
      ) do |server|
        app.config.before_initialize do
          # Register a custom middleware to register tools depending on `include_fs_tools` query parameter
          server.register_tools(*Tidewave::ToolResolver::ALL_TOOLS)
          app.middleware.use Tidewave::ToolResolver, server
        end
      end
    end

    # Install generator to set up necessary files in the host application
    generators do
      require "generators/tidewave/install/install_generator"
    end
  end
end
