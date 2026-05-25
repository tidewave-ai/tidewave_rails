# frozen_string_literal: true

require "ipaddr"
require "json"
require "rack/request"
require "fast_mcp"
require "tidewave/version"
require "tidewave/tool"
require "tidewave/database_adapter"
require "tidewave/tools/base"
require "tidewave/railtie" if defined?(Rails::Railtie)

gem_tools_path = File.expand_path("tidewave/tools/**/*.rb", __dir__)
Dir[gem_tools_path].sort.each do |file|
  next if file.end_with?("/base.rb")

  require file
end

class Tidewave
  TIDEWAVE_ROUTE = "tidewave".freeze
  MCP_ROUTE = "mcp".freeze
  CONFIG_ROUTE = "config".freeze
  PROTOCOL_VERSION = "2025-03-26".freeze

  INVALID_IP = <<~TEXT.freeze
    For security reasons, Tidewave does not accept remote connections by default.

    If you really want to allow remote connections, configure Tidewave with the `allow_remote_access: true` option
  TEXT

  INVALID_ORIGIN = "For security reasons, Tidewave does not accept requests with an origin header for this endpoint.".freeze

  DEFAULT_OPTIONS = {
    allow_remote_access: false,
    client_url: "https://tidewave.ai",
    framework_type: "unknown",
    project_name: "unknown",
    team: {}
  }.freeze

  module DatabaseAdapters
    # This module is defined here to ensure it's available for autoloading.
    # Individual adapters are loaded on-demand in database_adapter.rb.
  end

  def initialize(app, options = {})
    @app = app
    @options = DEFAULT_OPTIONS.merge(options || {})
    @logger = @options[:logger]
    @tools = build_tool_registry
  end

  def call(env)
    request = Rack::Request.new(env)
    path = request.path.split("/").reject(&:empty?)

    if path[0] == TIDEWAVE_ROUTE
      return forbidden(INVALID_IP) unless valid_client_ip?(request)
      return forbidden(INVALID_ORIGIN) if request.get_header("HTTP_ORIGIN") && path != [ TIDEWAVE_ROUTE ]

      case [ request.request_method, path ]
      when [ "GET", [ TIDEWAVE_ROUTE ] ]
        return home_endpoint(request)
      when [ "GET", [ TIDEWAVE_ROUTE, CONFIG_ROUTE ] ]
        return config_endpoint(request)
      when [ "POST", [ TIDEWAVE_ROUTE, MCP_ROUTE ] ]
        return mcp_endpoint(request)
      end

      return not_found
    end

    @app.call(env)
  end

  private

  def home_endpoint(_request)
    client_url = @options[:client_url].to_s.sub(%r{/\z}, "")
    body = <<~HTML
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="UTF-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1.0" />
          <script type="module" src="#{client_url}/tc/tc.js"></script>
        </head>
        <body></body>
      </html>
    HTML

    [ 200, response_headers("text/html", body), [ body ] ]
  end

  def config_endpoint(_request)
    json_response(config_data)
  end

  def mcp_endpoint(request)
    body = request.body.read

    message = JSON.parse(body)
    validation_error = validate_jsonrpc_message(message)
    return jsonrpc_error_response(nil, -32600, validation_error) if validation_error

    response = handle_mcp_message(message)
    return json_response({ "status" => "ok" }, status: 202) if response.nil?

    json_response(response)
  rescue JSON::ParserError
    jsonrpc_error_response(nil, -32700, "Parse error")
  rescue StandardError => error
    @logger&.error("Error handling MCP request: #{error.message}")
    jsonrpc_error_response(nil, -32603, "Internal error")
  end

  def config_data
    {
      "project_name" => @options[:project_name],
      "framework_type" => @options[:framework_type],
      "team" => @options[:team] || {},
      "tidewave_version" => VERSION
    }
  end

  def json_response(payload, status: 200)
    body = JSON.generate(payload)
    [ status, response_headers("application/json", body), [ body ] ]
  end

  def forbidden(message)
    @logger&.warn(message)
    text_response(403, message)
  end

  def not_found
    text_response(404, "Not Found")
  end

  def text_response(status, message)
    [ status, response_headers("text/plain; charset=utf-8", message), [ message ] ]
  end

  def response_headers(content_type, body)
    {
      "Content-Type" => content_type,
      "Content-Length" => body.bytesize.to_s
    }
  end

  def valid_client_ip?(request)
    return true if @options[:allow_remote_access]

    ip = request.ip
    return false if ip.nil? || ip.empty?

    address = IPAddr.new(ip)
    address.loopback? || address == IPAddr.new("::ffff:127.0.0.1")
  rescue IPAddr::InvalidAddressError
    false
  end

  def validate_jsonrpc_message(message)
    return "Message must be a JSON object" unless message.is_a?(Hash)
    return "Invalid JSON-RPC version" unless message["jsonrpc"] == "2.0"

    has_id = message.key?("id")
    has_method = message.key?("method")
    has_result = message.key?("result")

    return nil if has_method
    return nil if has_id && has_result

    "Invalid JSON-RPC message structure"
  end

  def handle_mcp_message(message)
    method = message["method"]
    request_id = message["id"]
    params = message["params"].is_a?(Hash) ? message["params"] : {}

    case method
    when "notifications/initialized", "notifications/cancelled"
      nil
    when "ping"
      jsonrpc_success_response(request_id, {})
    when "initialize"
      handle_initialize(request_id, params)
    when "tools/list"
      jsonrpc_success_response(request_id, { "tools" => tool_definitions })
    when "tools/call"
      handle_tool_call(request_id, params)
    else
      {
        "jsonrpc" => "2.0",
        "id" => request_id,
        "error" => {
          "code" => -32601,
          "message" => "Method not found",
          "data" => { "name" => method }
        }
      }
    end
  end

  def handle_initialize(request_id, params)
    client_version = params["protocolVersion"]
    return jsonrpc_error_response_body(request_id, -32602, "Protocol version is required") if client_version.nil? || client_version.empty?

    if client_version < PROTOCOL_VERSION
      return jsonrpc_error_response_body(
        request_id,
        -32602,
        "Unsupported protocol version. Server supports #{PROTOCOL_VERSION} or later"
      )
    end

    jsonrpc_success_response(request_id, {
      "protocolVersion" => PROTOCOL_VERSION,
      "capabilities" => { "tools" => { "listChanged" => false } },
      "serverInfo" => {
        "name" => "tidewave",
        "version" => VERSION
      },
      "tools" => tool_definitions
    })
  end

  def handle_tool_call(request_id, params)
    tool_name = params["name"]
    arguments = params["arguments"].is_a?(Hash) ? params["arguments"] : {}

    return jsonrpc_error_response_body(request_id, -32602, "Tool name is required") if tool_name.nil? || tool_name.empty?

    tool = @tools[tool_name]
    return jsonrpc_error_response_body(request_id, -32601, "Tool '#{tool_name}' not found") if tool.nil?

    result = tool.call(arguments)
    jsonrpc_success_response(request_id, result)
  rescue StandardError => error
    @logger&.error("Tool execution error: #{error.message}")
    jsonrpc_success_response(request_id, tool_error_result("Tool execution failed: #{error.message}"))
  end

  def jsonrpc_success_response(request_id, result)
    {
      "jsonrpc" => "2.0",
      "id" => request_id,
      "result" => result
    }
  end

  def jsonrpc_error_response(request_id, code, message)
    json_response(jsonrpc_error_response_body(request_id, code, message))
  end

  def jsonrpc_error_response_body(request_id, code, message)
    {
      "jsonrpc" => "2.0",
      "id" => request_id,
      "error" => {
        "code" => code,
        "message" => message
      }
    }
  end

  def tool_definitions
    @tools.values.map(&:definition)
  end

  def tool_error_result(message)
    {
      "content" => [
        {
          "type" => "text",
          "text" => message
        }
      ],
      "isError" => true
    }
  end

  def build_tool_registry
    Tidewave::Tool.descendants.map(&:new).each_with_object({}) do |tool, registry|
      name = tool.definition["name"]
      registry[name] = tool if name
    end
  end
end
