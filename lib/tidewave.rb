# frozen_string_literal: true

require "fileutils"
require "ipaddr"
require "json"
require "pathname"
require "rack/request"
require "uri"
require "tidewave/version"
require "tidewave/tool"
require "tidewave/database_adapter"
require "tidewave/magic_bytes"
require "tidewave/railtie" if defined?(Rails::Railtie)

class Tidewave
  module DatabaseAdapters
    # This module is defined here to ensure it's available for autoloading.
    # Individual adapters are loaded on-demand in database_adapter.rb.
  end

  module Tools
    # This module is defined here to ensure it's available for autoloading.
  end
end

gem_tools_path = File.expand_path("tidewave/tools/**/*.rb", __dir__)
Dir[gem_tools_path].sort.each do |file|
  require file
end

class Tidewave
  TIDEWAVE_ROUTE = "tidewave".freeze
  MCP_ROUTE = "mcp".freeze
  CONFIG_ROUTE = "config".freeze
  UPLOAD_ROUTE = "upload".freeze
  PROTOCOL_VERSION = "2025-03-26".freeze
  MAX_UPLOAD_SIZE = 10_000_000
  ALLOWED_UPLOAD_CONTENT_TYPES = [ "image/png", "image/jpeg", "video/webm" ].freeze
  ALLOWED_UPLOAD_TYPES = [ "screenshot", "recording" ].freeze
  TMP_DIR = "tmp".freeze

  INVALID_IP = <<~TEXT.freeze
    For security reasons, Tidewave does not accept remote connections by default.

    If you really want to allow remote connections, configure Tidewave with the `allow_remote_access: true` option
  TEXT

  INVALID_ORIGIN = "For security reasons, Tidewave does not accept requests with an origin header for this endpoint.".freeze
  INVALID_UPLOAD = "Bad Request: missing or invalid file parameter".freeze

  DEFAULT_OPTIONS = {
    allow_remote_access: false,
    client_url: "https://tidewave.ai",
    framework_type: "rack",
    team: {}
  }.freeze

  def initialize(app, options = {})
    @app = app
    @options = DEFAULT_OPTIONS.merge(options || {})
    raise ArgumentError, "project_name is required" if @options[:project_name].to_s.empty?

    @logger = @options[:logger]
    @root = @options[:root] ? Pathname.new(@options[:root].to_s) : Pathname.pwd
    @tools = build_tool_registry
  end

  def call(env)
    request = Rack::Request.new(env)
    path = request.path.split("/").reject(&:empty?)

    if path[0] == TIDEWAVE_ROUTE
      return forbidden(INVALID_IP) unless valid_client_ip?(request)

      return forbidden(INVALID_ORIGIN) if request.get_header("HTTP_ORIGIN") && !origin_allowed_path?(path)

      case [ request.request_method, path ]
      when [ "GET", [ TIDEWAVE_ROUTE ] ]
        home_endpoint(request)
      when [ "GET", [ TIDEWAVE_ROUTE, CONFIG_ROUTE ] ]
        config_endpoint(request)
      when [ "POST", [ TIDEWAVE_ROUTE, MCP_ROUTE ] ]
        mcp_endpoint(request)
      when [ "POST", [ TIDEWAVE_ROUTE, UPLOAD_ROUTE ] ]
        upload_endpoint(request)
      else
        # The MCP Streamable HTTP transport requires the MCP endpoint to answer
        # non-POST methods with 405 (GET without SSE support, DELETE, etc.)
        path == [ TIDEWAVE_ROUTE, MCP_ROUTE ] ? method_not_allowed() : not_found()
      end
    else
      strip_x_frame_options(@app.call(env))
    end
  end

  private

  def strip_x_frame_options(response)
    status, headers, body = response
    headers.delete("x-frame-options")
    [ status, headers, body ]
  end

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

  def config_endpoint(request)
    json_response(config_data(request), headers: { "access-control-allow-origin" => "*" })
  end

  def mcp_endpoint(request)
    message = JSON.parse(request.body.read)

    if message.is_a?(Array)
      handle_mcp_batch(message)
    else
      handle_mcp_single(message)
    end
  rescue JSON::ParserError
    jsonrpc_error_response(nil, -32700, "Parse error", status: 400)
  rescue StandardError => error
    @logger&.error("Error handling MCP request: #{error.message}")
    jsonrpc_error_response(nil, -32603, "Internal error")
  end

  def handle_mcp_single(message)
    validation_error = validate_jsonrpc_message(message)
    return jsonrpc_error_response(nil, -32600, validation_error, status: 400) if validation_error

    response = handle_mcp_message(message)
    response.nil? ? accepted_response : json_response(response)
  end

  def handle_mcp_batch(messages)
    return jsonrpc_error_response(nil, -32600, "Invalid Request", status: 400) if messages.empty?

    responses = messages.map { |message| handle_mcp_batch_message(message) }.compact
    responses.empty? ? accepted_response : json_response(responses)
  end

  def handle_mcp_batch_message(message)
    validation_error = validate_jsonrpc_message(message)
    return jsonrpc_error_response_body(nil, -32600, validation_error) if validation_error

    handle_mcp_message(message)
  end

  def config_data(request)
    {
      "project_name" => @options[:project_name],
      "framework_type" => @options[:framework_type],
      "orm_adapter" => @options[:orm_adapter],
      "team" => @options[:team] || {},
      "tidewave_version" => VERSION,
      "local_port" => local_port(request),
      "tmp_dir" => TMP_DIR
    }
  end

  def upload_endpoint(request)
    return text_response(400, INVALID_UPLOAD) if upload_too_large?(request)

    params = request.POST
    type = params["type"]
    upload = normalize_upload(params["file"])

    unless ALLOWED_UPLOAD_TYPES.include?(type) && allowed_upload?(upload)
      return text_response(400, INVALID_UPLOAD)
    end

    FileUtils.mkdir_p(upload_dir(type))
    destination = upload_path(type, upload[:filename])
    FileUtils.cp(upload[:path], destination)

    json_response({ "status" => "ok", "path" => relative_path_from_root(destination) })
  rescue ArgumentError
    text_response(400, INVALID_UPLOAD)
  end

  def json_response(payload, status: 200, headers: {})
    body = JSON.generate(payload)
    [ status, response_headers("application/json", body).merge(headers), [ body ] ]
  end

  def forbidden(message)
    @logger&.warn(message)
    text_response(403, message)
  end

  def not_found
    text_response(404, "Not Found")
  end

  def method_not_allowed
    status, headers, body = text_response(405, "Method Not Allowed")
    [ status, headers.merge("allow" => "POST"), body ]
  end

  def accepted_response
    [ 202, { "content-length" => "0" }, [] ]
  end

  def text_response(status, message)
    [ status, response_headers("text/plain; charset=utf-8", message), [ message ] ]
  end

  # Rack 3 requires response header keys to be lowercase. Capitalized keys break
  # case-sensitive middleware such as Rack::Deflater, which strips "content-length"
  # before gzipping; a surviving "Content-Length" leaves a stale (uncompressed)
  # length on the compressed body and hangs spec-compliant HTTP clients.
  def response_headers(content_type, body)
    {
      "content-type" => content_type,
      "content-length" => body.bytesize.to_s
    }
  end

  def origin_allowed_path?(path)
    [
      [ TIDEWAVE_ROUTE ],
      [ TIDEWAVE_ROUTE, CONFIG_ROUTE ],
      [ TIDEWAVE_ROUTE, UPLOAD_ROUTE ]
    ].include?(path)
  end

  def local_port(request)
    sock = request.env["puma.socket"]
    return unless sock

    addr = sock.respond_to?(:local_address) ? sock.local_address : sock.to_io.local_address
    addr.ip? ? addr.ip_port : nil
  end

  def valid_client_ip?(request)
    return true if @options[:allow_remote_access]

    ip = request.get_header("REMOTE_ADDR")
    return false if ip.nil? || ip.empty?

    address = IPAddr.new(ip)
    address.loopback? || address == IPAddr.new("::ffff:127.0.0.1")
  rescue IPAddr::InvalidAddressError
    false
  end

  def upload_too_large?(request)
    request.content_length && request.content_length.to_i > MAX_UPLOAD_SIZE
  end

  def normalize_upload(upload)
    case upload
    when Hash
      tempfile = upload[:tempfile] || upload["tempfile"]
      {
        filename: upload[:filename] || upload["filename"],
        content_type: upload[:type] || upload["type"],
        path: tempfile&.path
      }
    else
      return {} unless upload.respond_to?(:original_filename) && upload.respond_to?(:content_type)

      {
        filename: upload.original_filename,
        content_type: upload.content_type,
        path: upload.tempfile&.path
      }
    end
  end

  def allowed_upload?(upload)
    ALLOWED_UPLOAD_CONTENT_TYPES.include?(upload[:content_type].to_s.split(";").first) &&
      upload[:path] &&
      Tidewave::MagicBytes.type(File.binread(upload[:path], 128)) != :unknown
  end

  def upload_dir(type)
    @root.join(TMP_DIR, "tidewave", folder_for_upload_type(type)).to_s
  end

  def upload_path(type, filename)
    filename = filename.to_s

    unless filename.match?(/\A[A-Za-z0-9_.-]+\z/) && !filename.include?("..")
      raise ArgumentError, "filename must only contain numbers, letters, hyphens, and underscores: #{filename}"
    end

    unless [ ".png", ".jpg", ".jpeg", ".webm" ].include?(File.extname(filename).downcase)
      raise ArgumentError, "filename must have a valid extension (.png, .jpg, .jpeg, .webm): #{filename}"
    end

    File.join(upload_dir(type), filename)
  end

  def folder_for_upload_type(type)
    case type
    when "screenshot"
      "screenshots"
    when "recording"
      "recordings"
    end
  end

  def relative_path_from_root(path)
    Pathname.new(path).relative_path_from(@root).to_s
  end

  def validate_jsonrpc_message(message)
    return "Message must be a JSON object" unless message.is_a?(Hash)
    return "Invalid JSON-RPC version" unless message["jsonrpc"] == "2.0"

    has_id = message.key?("id")
    has_method = message.key?("method")
    has_result = message.key?("result") || message.key?("error")

    return nil if has_method
    return nil if has_id && has_result

    "Invalid JSON-RPC message structure"
  end

  # Returns the JSON-RPC response for a request, or nil for messages that
  # must not be replied to (notifications and client-sent responses), which
  # the transport acknowledges with 202 Accepted.
  def handle_mcp_message(message)
    return nil unless message.key?("method") && message.key?("id")

    method = message["method"]
    request_id = message["id"]
    params = message["params"].is_a?(Hash) ? message["params"] : {}

    case method
    when "ping"
      jsonrpc_success_response_body(request_id, {})
    when "initialize"
      handle_initialize(request_id, params)
    when "tools/list"
      jsonrpc_success_response_body(request_id, { "tools" => tool_definitions })
    when "tools/call"
      handle_tool_call(request_id, params)
    when "prompts/list"
      jsonrpc_success_response_body(request_id, { "prompts" => [] })
    when "resources/list"
      jsonrpc_success_response_body(request_id, { "resources" => [] })
    when "resources/templates/list"
      jsonrpc_success_response_body(request_id, { "resourceTemplates" => [] })
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

    # Version negotiation: when the client requests a version we don't
    # support, we respond with the version we do support and the client
    # decides whether to continue or disconnect.
    jsonrpc_success_response_body(request_id, {
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

    result = tool.validate_and_call(arguments)
    jsonrpc_success_response_body(request_id, tool_result(result))
  rescue StandardError => error
    @logger&.error("Tool execution error: #{error.message}")
    jsonrpc_success_response_body(request_id, tool_error_result("Tool execution failed: #{error.message}"))
  end

  def jsonrpc_success_response_body(request_id, result)
    {
      "jsonrpc" => "2.0",
      "id" => request_id,
      "result" => result
    }
  end

  def jsonrpc_error_response(request_id, code, message, status: 200)
    json_response(jsonrpc_error_response_body(request_id, code, message), status: status)
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
      "content" => [ text_content(message) ],
      "isError" => true
    }
  end

  def tool_result(result)
    if result.is_a?(Hash)
      {
        "content" => [ text_content(JSON.generate(result)) ],
        "structuredContent" => result
      }
    else
      {
        "content" => [ text_content(result.to_s) ]
      }
    end
  end

  def text_content(text)
    {
      "type" => "text",
      "text" => text
    }
  end

  def build_tool_registry
    Tidewave::Tool.descendants.each_with_object({}) do |tool_class, registry|
      tool = tool_class.new(@options)
      definition = tool.definition
      next if definition.nil?

      name = definition["name"]
      registry[name] = tool if name
    end
  end
end
