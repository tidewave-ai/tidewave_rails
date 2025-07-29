# frozen_string_literal: true

require "fast_mcp"
require "rack/request"
require "active_support/core_ext/class"

class Tidewave::Middleware
  TIDEWAVE_ROUTE = "tidewave".freeze
  SSE_ROUTE = "mcp".freeze
  MESSAGES_ROUTE = "mcp/message".freeze

  INVALID_IP = <<~TEXT.freeze
    For security reasons, Tidewave does not accept remote connections by default.

    If you really want to allow remote connections, set `config.tidewave.allow_remote_access = true`.
  TEXT

  def initialize(app, config)
    @allow_remote_access = config.allow_remote_access

    @app = FastMcp.rack_middleware(app,
      name: "tidewave",
      version: Tidewave::VERSION,
      path_prefix: "/" + TIDEWAVE_ROUTE,
      messages_route: MESSAGES_ROUTE,
      sse_route: SSE_ROUTE,
      logger: config.logger || Logger.new(Rails.root.join("log", "tidewave.log")),
      # Rails runs the HostAuthorization in dev, so we skip this
      allowed_origins: [],
      # We validate this one in Tidewave::Middleware
      localhost_only: false
    ) do |server|
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

  def call(env)
    request = Rack::Request.new(env)
    path = request.path.split("/").reject(&:empty?)

    if path[0] == TIDEWAVE_ROUTE
      return forbidden(INVALID_IP) unless valid_client_ip?(request)

      # The MCP routes are handled downstream by FastMCP
      case path
      when [TIDEWAVE_ROUTE]
        return home(request)
      end
    end

    @app.call(env)
  end

  private

  def home(request)
    user_agent = request.user_agent
    host = request.host

    html = <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <title>Tidewave</title>
      </head>
      <body>
        <h1>Welcome to Tidewave</h1>
        <p>Host: #{host}</p>
        <p>User Agent: #{user_agent}</p>
      </body>
      </html>
    HTML

    [ 200, { "Content-Type" => "text/html" }, [ html ] ]
  end

  def forbidden(message)
    [ 403, { "Content-Type" => "text/plain" }, [ message ] ]
  end

  def valid_client_ip?(request)
    return true if @allow_remote_access

    ip = request.ip
    return false unless ip

    addr = IPAddr.new(ip)

    addr.loopback? ||
    addr == IPAddr.new('127.0.0.1') ||
    addr == IPAddr.new('::1') ||
    addr == IPAddr.new('::ffff:127.0.0.1')  # IPv4-mapped IPv6
  end
end
