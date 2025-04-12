# frozen_string_literal: true

require "fast_mcp"
require "logger"
require "fileutils"

module Tidewave
  class Railtie < Rails::Railtie
    initializer "tidewave.setup_mcp" do |app|
      # Set up MCP server with the host application
      FastMcp.mount_in_rails(
        app,
        name: "tidewave-tools",
        version: Tidewave::VERSION,
        path_prefix: "/tidewave",
        messages_route: "messages",
        sse_route: "mcp",
        logger: Logger.new(STDOUT)
      ) do |server|
        app.config.after_initialize do
          # First, load and register the precoded tools from the gem
          gem_tools_path = File.expand_path("../../app/tools/**/*.rb", __dir__)
          Dir[gem_tools_path].each { |f| require f }

          # Then, load tools from the host application
          app_tools_path = Rails.root.join("app", "tools", "**", "*.rb")
          Dir[app_tools_path].each { |f| require f }

          # Register all tools with the MCP server
          if defined?(ApplicationTool)
            server.register_tools(*ApplicationTool.descendants)
          end
        end
      end
    end

    # Install generator to set up necessary files in the host application
    generators do
      require "generators/tidewave/install/install_generator"
    end
  end
end
