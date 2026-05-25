# frozen_string_literal: true

require "ipaddr"
require "json"
require "rack/request"
require "tidewave/version"
require "tidewave/database_adapter"
require "tidewave/railtie" if defined?(Rails::Railtie)

class Tidewave
  TIDEWAVE_ROUTE = "tidewave".freeze
  MCP_ROUTE = "mcp".freeze
  CONFIG_ROUTE = "config".freeze

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
    @mcp_app = @options[:mcp_app]
  end

  def call(env)
    request = Rack::Request.new(env)
    path = request.path.split("/").reject(&:empty?)

    if path[0] == TIDEWAVE_ROUTE
      return forbidden(INVALID_IP) unless valid_client_ip?(request)
      return forbidden(INVALID_ORIGIN) if request.get_header("HTTP_ORIGIN") && path != [ TIDEWAVE_ROUTE ]

      case [ request.request_method, path ]
      when [ "GET", [ TIDEWAVE_ROUTE ] ]
        return home(request)
      when [ "GET", [ TIDEWAVE_ROUTE, CONFIG_ROUTE ] ]
        return config_endpoint(request)
      when [ "POST", [ TIDEWAVE_ROUTE, MCP_ROUTE ] ]
        return @mcp_app.call(env) if @mcp_app
      end

      return not_found
    end

    @app.call(env)
  end

  private

  def home(_request)
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

  def config_data
    {
      "project_name" => @options[:project_name],
      "framework_type" => @options[:framework_type],
      "team" => @options[:team] || {},
      "tidewave_version" => VERSION
    }
  end

  def json_response(payload)
    body = JSON.generate(payload)
    [ 200, response_headers("application/json", body), [ body ] ]
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
end
