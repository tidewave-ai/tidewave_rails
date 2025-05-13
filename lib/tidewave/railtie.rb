# frozen_string_literal: true

require "fast_mcp"
require "logger"
require "fileutils"
require "tidewave/tool_resolver"
require "tidewave/configuration"

module Tidewave
  class Railtie < Rails::Railtie
    config.tidewave = Tidewave::Configuration.new


    initializer "tidewave.setup_mcp" do |app|
      # Skip in test environments
      if Rails.env.test?
        Rails.logger.info("[Tidewave] Skipping MCP setup when testing")
        next
      end

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
          # Register a custom middleware to register tools depending on `include_fs_tools` query parameter
          server.register_tools(*Tidewave::ToolResolver::ALL_TOOLS)
          app.middleware.use Tidewave::ToolResolver, server
        end
      end
    end
  end
end
