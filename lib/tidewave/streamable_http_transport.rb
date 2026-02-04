# frozen_string_literal: true

require "json"
require "rack"
require "fast_mcp"

module Tidewave
  # Streamable HTTP transport for MCP (POST-only, no SSE)
  # This transport implements a simplified version of the MCP Streamable HTTP protocol
  # that only supports POST requests for JSON-RPC messages. Unlike the full protocol,
  # it does not support Server-Sent Events (SSE) for streaming responses.
  class StreamableHttpTransport < FastMcp::Transports::BaseTransport
    attr_reader :app, :path

    def initialize(app, server, options = {})
      super(server, logger: options[:logger])
      @app = app
      @path = options[:path_prefix] || "/mcp"
      @running = false
    end

    def start
      @logger.debug("Starting Streamable HTTP transport (POST-only) at path: #{@path}")
      @running = true
    end

    def stop
      @logger.debug("Stopping Streamable HTTP transport")
      @running = false
    end

    # Send a message - capture response for synchronous HTTP
    # Required by FastMCP::Transports::BaseTransport interface
    def send_message(message)
      @logger.debug("send_message called, capturing response: #{message.inspect}")
      @captured_response = message
    end

    def call(env)
      request = Rack::Request.new(env)

      if request.path == @path
        @server.transport = self
        handle_mcp_request(request, env)
      else
        @app.call(env)
      end
    end

    private

    def handle_mcp_request(request, env)
      if request.post?
        handle_post_request(request)
      else
        method_not_allowed_response
      end
    end

    def handle_post_request(request)
      @logger.debug("Received POST request to MCP endpoint")

      begin
        body = request.body.read
        message = JSON.parse(body)

        @logger.debug("Processing message: #{message.inspect}")

        unless valid_jsonrpc_message?(message)
          return json_rpc_error_response(400, -32600, "Invalid Request", nil)
        end

        # Capture the response that will be sent via send_message
        @captured_response = nil
        @server.handle_json_request(message)

        @logger.debug("Sending response: #{@captured_response.inspect}")

        if @captured_response
          [
            200,
            { "Content-Type" => "application/json" },
            [ JSON.generate(@captured_response) ]
          ]
        else
          [ 202, { }, [] ]
        end
      rescue JSON::ParserError => e
        @logger.error("Invalid JSON in request: #{e.message}")
        json_rpc_error_response(400, -32700, "Parse error", nil)
      rescue => e
        @logger.error("Error processing message: #{e.message}")
        @logger.error(e.backtrace.join("\n")) if e.backtrace
        json_rpc_error_response(500, -32603, "Internal error", nil)
      end
    end

    def valid_jsonrpc_message?(message)
      return false unless message.is_a?(Hash)
      return false unless message["jsonrpc"] == "2.0"

      message.key?("method") || message.key?("result") || message.key?("error")
    end

    def method_not_allowed_response
      [
        405,
        { "Content-Type" => "application/json" },
        [ JSON.generate({
          jsonrpc: "2.0",
          error: {
            code: -32601,
            message: "Method not allowed. This endpoint only supports POST requests."
          },
          id: nil
        }) ]
      ]
    end

    def json_rpc_error_response(http_status, code, message, id)
      [
        http_status,
        { "Content-Type" => "application/json" },
        [ JSON.generate({
          jsonrpc: "2.0",
          error: {
            code: code,
            message: message
          },
          id: id
        }) ]
      ]
    end
  end
end
