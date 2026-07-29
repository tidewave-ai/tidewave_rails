# frozen_string_literal: true

require "fileutils"
require "cgi"
require "ipaddr"
require "json"
require "pathname"
require "rack/request"
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
  class ToolbarBody
    def initialize(body, toolbar)
      @body = body
      @toolbar = toolbar
      @closed = false
    end

    def each
      return enum_for(:each) unless block_given?

      pending = +""
      injected = false

      @body.each do |part|
        if injected
          yield part
        else
          pending << part

          if closing_head = pending.downcase.index("</head>")
            toolbar = @toolbar.dup.force_encoding(pending.encoding)
            output = pending.insert(closing_head, toolbar)
            pending = nil
            injected = true
            yield output
          end
        end
      end

      yield pending unless injected || pending.empty?
    end

    def close
      return if @closed

      @closed = true
      @body.close if @body.respond_to?(:close)
    end
  end

  TIDEWAVE_ROUTE = "tidewave".freeze
  MCP_ROUTE = "mcp".freeze
  CONFIG_ROUTE = "config".freeze
  CONNECT_ROUTE = "connect".freeze
  UPLOAD_ROUTE = "upload".freeze
  WS_ROUTE = "ws".freeze
  PROTOCOL_VERSION = "2025-03-26".freeze
  MAX_UPLOAD_SIZE = 10_000_000
  ALLOWED_UPLOAD_CONTENT_TYPES = [ "image/png", "image/jpeg", "video/webm" ].freeze
  ALLOWED_UPLOAD_TYPES = [ "screenshot", "recording" ].freeze
  TMP_DIR = "tmp".freeze

  INVALID_IP = <<~TEXT.freeze
    For security reasons, Tidewave does not accept remote connections by default.

    If you really want to allow remote connections, configure Tidewave with the `allow_remote_access: true` option
  TEXT

  INVALID_FETCH_SITE = "For security reasons, Tidewave only accepts requests from the same origin your web app is running on.".freeze
  INVALID_ORIGIN = "For security reasons, Tidewave does not accept requests with an origin header for this endpoint.".freeze
  INVALID_UPLOAD = "Bad Request: missing or invalid file parameter".freeze
  ENCODED_HTML_WARNING = <<~TEXT.freeze
    Tidewave could not inject the toolbar because the HTML response is encoded.

    If you use Rack::Deflater or another compression middleware, place it before Tidewave in the middleware stack.
  TEXT

  DEFAULT_OPTIONS = {
    allow_remote_access: false,
    browser_control: nil,
    client_url: "https://tidewave.ai",
    framework_type: "rack",
    team: {},
    toolbar: true
  }.freeze

  def initialize(app, options = {})
    @app = app
    @options = DEFAULT_OPTIONS.merge(options || {})
    raise ArgumentError, "project_name is required" if @options[:project_name].to_s.empty?

    @logger = @options[:logger]
    @root = @options[:root] ? Pathname.new(@options[:root].to_s) : Pathname.pwd
    @browser_control = @options[:browser_control]
    @tools = build_tool_registry
  end

  def call(env)
    request = Rack::Request.new(env)
    path = request.path.split("/").reject(&:empty?)

    if path[0] == TIDEWAVE_ROUTE
      return forbidden(INVALID_IP) unless valid_client_ip?(request)

      origin_error = check_origin(request, path)
      return origin_error if origin_error

      case [ request.request_method, path ]
      when [ "GET", [ TIDEWAVE_ROUTE ] ]
        home_endpoint(request)
      when [ "GET", [ TIDEWAVE_ROUTE, WS_ROUTE ] ]
        unless @browser_control
          raise "this route is currently only supported for Rails"
        end

        @browser_control.call(request.env)
      when [ "GET", [ TIDEWAVE_ROUTE, CONNECT_ROUTE ] ]
        app_endpoint(request)
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
      inject_toolbar(request, strip_x_frame_options(@app.call(env)))
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

  def app_endpoint(request)
    client_url = @options[:client_url].to_s.sub(%r{/\z}, "")
    body = <<~HTML
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="UTF-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1.0" />
          #{config_meta_tag(request)}
          <script type="module" src="#{client_url}/tc/control.js"></script>
        </head>
        <body></body>
      </html>
    HTML

    headers = response_headers("text/html", body)
    headers["content-security-policy"] = "base-uri 'self'; frame-ancestors 'self';"
    [ 200, headers, [ body ] ]
  end

  def config_endpoint(request)
    json_response(config_data(request), headers: { "access-control-allow-origin" => "*" })
  end

  # Returns a 403 response when the request is not allowed for the given
  # path, nil otherwise.
  def check_origin(request, path)
    case path
    when [ TIDEWAVE_ROUTE ], [ TIDEWAVE_ROUTE, CONNECT_ROUTE ], [ TIDEWAVE_ROUTE, CONFIG_ROUTE ],
         [ TIDEWAVE_ROUTE, WS_ROUTE ], [ TIDEWAVE_ROUTE, UPLOAD_ROUTE ]
      # Browser-facing routes are subject to the fetch metadata policy
      forbidden(INVALID_FETCH_SITE) unless allowed_fetch_site?(request, path)
    else
      # The MCP endpoint (and everything else) is meant for MCP clients
      # and never the browser, so we reject even same-origin browser
      # requests (browsers set the origin header on all POST requests)
      forbidden(INVALID_ORIGIN) unless request.get_header("HTTP_ORIGIN").nil?
    end
  end

  def allowed_fetch_site?(request, path)
    # Note that these checks do not prevent DNS rebinding, but Rails
    # already guards against it through the HostAuthorization middleware.

    fetch_site = request.get_header("HTTP_SEC_FETCH_SITE")
    fetch_mode = request.get_header("HTTP_SEC_FETCH_MODE")
    fetch_dest = request.get_header("HTTP_SEC_FETCH_DEST")

    # Same-origin request or user-originated request.
    return true if fetch_site.nil? || [ "same-origin", "none" ].include?(fetch_site)

    # /config contains metadata for discovery and it is safe to allow
    # any origin.
    return true if path == [ TIDEWAVE_ROUTE, CONFIG_ROUTE ]

    # Allow regular cross-site top-level navigations, such as following
    # a link to the /tidewave page. Form submissions are navigations too,
    # hence the GET check.
    return true if request.get? && fetch_mode == "navigate" && fetch_dest == "document"

    false
  end

  def mcp_endpoint(request)
    message = JSON.parse(request.body.read)
    context = mcp_context(request)

    if message.is_a?(Array)
      handle_mcp_batch(message, context)
    else
      handle_mcp_single(message, context)
    end
  rescue JSON::ParserError
    jsonrpc_error_response(nil, -32700, "Parse error", status: 400)
  rescue StandardError => error
    @logger&.error("Error handling MCP request: #{error.message}")
    jsonrpc_error_response(nil, -32603, "Internal error")
  end

  def mcp_context(request)
    tools = @tools

    if request.GET["include_browser_tools"] == "false"
      tools = tools.reject { |_name, tool| tool.browser_tool? }
    end

    { tools: tools, url: request.base_url }
  end

  def handle_mcp_single(message, context)
    validation_error = validate_jsonrpc_message(message)
    return jsonrpc_error_response(nil, -32600, validation_error, status: 400) if validation_error

    response = handle_mcp_message(message, context)
    response.nil? ? accepted_response : json_response(response)
  end

  def handle_mcp_batch(messages, context)
    return jsonrpc_error_response(nil, -32600, "Invalid Request", status: 400) if messages.empty?

    responses = messages.map { |message| handle_mcp_batch_message(message, context) }.compact
    responses.empty? ? accepted_response : json_response(responses)
  end

  def handle_mcp_batch_message(message, context)
    validation_error = validate_jsonrpc_message(message)
    return jsonrpc_error_response_body(nil, -32600, validation_error) if validation_error

    handle_mcp_message(message, context)
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

  def inject_toolbar(request, response)
    status, headers, body = response
    return response if @options[:toolbar] == false || !html_response?(headers)

    if encoded_response?(headers)
      warn_encoded_html
      return response
    end

    return response unless body.respond_to?(:each)

    delete_response_header(headers, "content-length")
    delete_response_header(headers, "etag")
    [ status, headers, ToolbarBody.new(body, toolbar_html(request)) ]
  end

  def html_response?(headers)
    content_types = Array(response_header(headers, "content-type"))

    content_types.any? { |content_type| content_type.to_s.downcase.start_with?("text/html") }
  end

  def encoded_response?(headers)
    Array(response_header(headers, "content-encoding")).any? do |content_encoding|
      content_encoding.to_s.split(",").any? do |encoding|
        !encoding.strip.empty? && encoding.strip.downcase != "identity"
      end
    end
  end

  def response_header(headers, name)
    key = headers.keys.find { |header| header.downcase == name }
    headers[key] if key
  end

  def delete_response_header(headers, name)
    headers.delete_if { |header, _value| header.downcase == name }
  end

  def warn_encoded_html
    return if @warned_encoded_html

    @warned_encoded_html = true
    @logger&.warn(ENCODED_HTML_WARNING)
  end

  def toolbar_html(request)
    client_url = @options[:client_url].to_s.sub(%r{/\z}, "")

    <<~HTML
      #{config_meta_tag(request)}
      <script async type="module" src="#{client_url}/tc/toolbar.js"></script>
    HTML
  end

  def config_meta_tag(request)
    payload = {
      "tidewave" => config_data(request),
      "root" => @root.to_s,
      "wsl_distro" => ENV["WSL_DISTRO_NAME"],
      "framework" => {}
    }

    %(<meta name="tidewave:config" content="#{CGI.escapeHTML(JSON.generate(payload))}" />)
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
  def handle_mcp_message(message, context)
    return nil unless message.key?("method") && message.key?("id")

    method = message["method"]
    request_id = message["id"]
    params = message["params"].is_a?(Hash) ? message["params"] : {}

    case method
    when "ping"
      jsonrpc_success_response_body(request_id, {})
    when "initialize"
      handle_initialize(request_id, params, context)
    when "tools/list"
      jsonrpc_success_response_body(request_id, { "tools" => tool_definitions(context) })
    when "tools/call"
      handle_tool_call(request_id, params, context)
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

  def handle_initialize(request_id, params, context)
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
      "tools" => tool_definitions(context)
    })
  end

  def handle_tool_call(request_id, params, context)
    tool_name = params["name"]
    arguments = params["arguments"].is_a?(Hash) ? params["arguments"] : {}

    return jsonrpc_error_response_body(request_id, -32602, "Tool name is required") if tool_name.nil? || tool_name.empty?

    tool = context[:tools][tool_name]
    return jsonrpc_error_response_body(request_id, -32601, "Tool '#{tool_name}' not found") if tool.nil?

    result = tool.validate_and_call(arguments, context)
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

  def tool_definitions(context)
    context[:tools].values.map(&:definition)
  end

  def tool_error_result(message)
    {
      "content" => [ text_content(message) ],
      "isError" => true
    }
  end

  def tool_result(result)
    if result.is_a?(Hash)
      # The tool returned a complete MCP result (browser_eval passes the
      # browser's reply, including isError, through verbatim)
      result
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
