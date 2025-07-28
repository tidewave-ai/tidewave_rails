# frozen_string_literal: true

require "fast_mcp"
require "rack/request"
require "active_support/core_ext/class"

class Tidewave::Middleware
  PATH_PREFIX = "/tidewave"
  SSE_ROUTE = "mcp"
  MESSAGES_ROUTE = "mcp/message"

  INVALID_IP = <<~TEXT
    For security reasons, Tidewave does not accept remote connections by default.

    If you really want to allow remote connections, set `config.tidewave.allow_remote_access = true`.
  TEXT

  def initialize(app, config)
    @allow_remote_access = config.allow_remote_access
    @allowed_ips = config.allowed_ips

    @app = FastMcp.rack_middleware(app,
      name: "tidewave",
      version: Tidewave::VERSION,
      path_prefix: PATH_PREFIX,
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

    if request.path.start_with?(PATH_PREFIX + "/")
      return forbidden(INVALID_IP) unless validate_client_ip(request)
    end

    @app.call(env)
  end

  private

  def forbidden(message)
    [ 403, {"Content-Type" => "text/plain"}, [ message ] ]
  end

  def validate_client_ip(request)
    @allow_remote_access || @allowed_ips.include?(request.ip)
  end
end
