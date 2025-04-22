# frozen_string_literal: true

require "rack"

gem_tools_path = File.expand_path("../../lib/tidewave/tools/**/*.rb", __dir__)
Dir[gem_tools_path].each { |f| require f }

module Tidewave
  class ToolResolver
    ALL_TOOLS = Tidewave::Tools::Base.descendants
    NON_FILE_SYSTEM_TOOLS = ALL_TOOLS.reject(&:file_system_tool?)
    SSE_PATH = "/tidewave/mcp".freeze

    def initialize(app, server)
      @app = app
      @server = server
    end

    def call(env)
      request = Rack::Request.new(env)

      # Resolve tools depending on the query parameters
      resolve_tool_list(request)

      # Forward the request to the underlying app (RackTransport)
      @app.call(env)
    end

    private

    def resolve_tool_list(request)
      # We only want to resolve tools when the path is SSE_PATH
      return unless request.path == SSE_PATH

      # Check if the include_fs_tools parameter is set to "true"
      # This allows clients to opt-in to file system access tools
      # by adding ?include_fs_tools=true to their SSE connection URL
      include_fs_tools = request.params["include_fs_tools"] == "true"

      # Reset server tools
      @server.instance_variable_set(:@tools, {})

      if include_fs_tools
        # Register all tools when file system access is explicitly requested
        @server.register_tools(*ALL_TOOLS)
      else
        # Otherwise only register non-file system tools
        @server.register_tools(*NON_FILE_SYSTEM_TOOLS)
      end
    end
  end
end
