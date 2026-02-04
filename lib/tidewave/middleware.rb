# frozen_string_literal: true

require "ipaddr"
require "fast_mcp"
require "rack/request"
require "active_support/core_ext/class"
require "active_support/core_ext/object/blank"
require "json"
require "erb"
require_relative "streamable_http_transport"

class Tidewave::Middleware
  TIDEWAVE_ROUTE = "tidewave".freeze
  MCP_ROUTE = "mcp".freeze
  CONFIG_ROUTE = "config".freeze

  INVALID_IP = <<~TEXT.freeze
    For security reasons, Tidewave does not accept remote connections by default.

    If you really want to allow remote connections, set `config.tidewave.allow_remote_access = true`.
  TEXT

  def initialize(app, config)
    @allow_remote_access = config.allow_remote_access
    @client_url = config.client_url
    @team = config.team
    @project_name = Rails.application.class.module_parent.name

    @app = FastMcp.rack_middleware(app,
      name: "tidewave",
      version: Tidewave::VERSION,
      path_prefix: "/" + TIDEWAVE_ROUTE + "/" + MCP_ROUTE,
      transport: Tidewave::StreamableHttpTransport,
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
      case [ request.request_method, path ]
      when [ "GET", [ TIDEWAVE_ROUTE ] ]
        return home(request)
      when [ "GET", [ TIDEWAVE_ROUTE, CONFIG_ROUTE ] ]
        return config_endpoint(request)
      end
    end

    status, headers, body = @app.call(env)

    # Remove X-Frame-Options headers for non-Tidewave routes to allow embedding.
    # CSP headers are configured in the CSP application environment.
    headers.delete("X-Frame-Options")

    [ status, headers, body ]
  end

  private

  def home(request)
    config = config_data

    html = <<~HTML
      <html>
        <head>
          <meta charset="UTF-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1.0" />
          <script type="module" src="#{@client_url}/tc/tc.js"></script>
        </head>
        <body></body>
      </html>
    HTML

    [ 200, { "Content-Type" => "text/html" }, [ html ] ]
  end

  def config_endpoint(request)
    [ 200, { "Content-Type" => "application/json" }, [ JSON.generate(config_data) ] ]
  end

  def config_data
    {
      "project_name" => @project_name,
      "framework_type" => "rails",
      "tidewave_version" => Tidewave::VERSION,
      "team" => @team
    }
  end

  def forbidden(message)
    Rails.logger.warn(message)
    [ 403, { "Content-Type" => "text/plain" }, [ message ] ]
  end

  def valid_client_ip?(request)
    return true if @allow_remote_access

    ip = request.ip
    return false unless ip

    addr = IPAddr.new(ip)

    addr.loopback? ||
    addr == IPAddr.new("127.0.0.1") ||
    addr == IPAddr.new("::1") ||
    addr == IPAddr.new("::ffff:127.0.0.1")  # IPv4-mapped IPv6
  end
end
