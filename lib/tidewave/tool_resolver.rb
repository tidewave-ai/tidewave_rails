# frozen_string_literal: true

require "rack"
require "json"
require "active_support/core_ext/class"

gem_tools_path = File.expand_path("tools/**/*.rb", __dir__)
Dir[gem_tools_path].each { |f| require f }

module Tidewave
  class ToolResolver
    ALL_TOOLS = Tidewave::Tools::Base.descendants
    NON_FILE_SYSTEM_TOOLS = ALL_TOOLS.reject(&:file_system_tool?)
    MESSAGES_PATH = "/tidewave/messages".freeze
    TOOLS_LIST_METHOD = "tools/list".freeze
    INCLUDE_FS_TOOLS_PARAM = "include_fs_tools".freeze

    def initialize(app, server)
      @app = app
      @server = server
    end

    def call(env)
      request = Rack::Request.new(env)
      request_path = request.path
      request_body = extract_request_body(request)
      request_params = request.params

      # Override tools list response if requested
      return override_tools_list_response(env) if overriding_tools_list_request?(request_path, request_params, request_body)

      # Forward the request to the underlying app (RackTransport)
      @app.call(env)
    end

    private

    def extract_request_body(request)
      JSON.parse(request.body.read)
    rescue JSON::ParserError => e
      {}
    ensure
      request.body.rewind
    end

    # When we want to exclude file system tools, we need to handle the request differently to prevent from listing them
    def overriding_tools_list_request?(request_path, request_params, request_body)
      request_path == MESSAGES_PATH && request_body["method"] == TOOLS_LIST_METHOD && request_params[INCLUDE_FS_TOOLS_PARAM] != "true"
    end

    RESPONSE_HEADERS = { "Content-Type" => "application/json" }

    def override_tools_list_response(env)
      register_non_file_system_tools
      @app.call(env).tap { register_all_tools }
    end

    def register_non_file_system_tools
      reset_server_tools
      @server.register_tools(*NON_FILE_SYSTEM_TOOLS)
    end

    def register_all_tools
      reset_server_tools
      @server.register_tools(*ALL_TOOLS)
    end

    def reset_server_tools
      @server.instance_variable_set(:@tools, {})
    end
  end
end
