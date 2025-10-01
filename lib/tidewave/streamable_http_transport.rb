# frozen_string_literal: true

require "json"
require "rack"

module Tidewave
  # Streamable HTTP transport for MCP (POST-only, no SSE)
  #
  # This transport implements a simplified version of the MCP Streamable HTTP protocol
  # that only supports POST requests for JSON-RPC messages. Unlike the full protocol,
  # it does not support Server-Sent Events (SSE) for streaming responses.
  #
  # This matches the implementation in tidewave_phoenix which also only supports POST.
  class StreamableHttpTransport
    attr_reader :app, :path

    def initialize(app, server, options = {})
      @app = app
      @server = server
      @path = options[:path_prefix] || "/mcp"
      @logger = options[:logger] || Logger.new($stdout)
      @running = false

      # Set this transport on the server so it can send messages back
      @server.transport = self
    end

    # Start the transport
    def start
      @logger.debug("Starting Streamable HTTP transport (POST-only) at path: #{@path}")
      @running = true
    end

    # Stop the transport
    def stop
      @logger.debug("Stopping Streamable HTTP transport")
      @running = false
    end

    # Send a message (no-op for non-streaming transport)
    # Required by FastMCP::Transports::BaseTransport interface
    def send_message(message)
      # This transport doesn't support server-initiated messages (no SSE)
      # Messages are only sent as HTTP responses to POST requests
      @logger.debug("send_message called but ignored (no streaming support)")
    end

    # Rack middleware call
    def call(env)
      request = Rack::Request.new(env)

      # Check if this is an MCP request
      if request.path == @path
        handle_mcp_request(request, env)
      else
        # Pass through to the next middleware/app
        @app.call(env)
      end
    end

    private

    def handle_mcp_request(request, env)
      if request.post?
        handle_post_request(request)
      elsif request.get?
        # Return 405 Method Not Allowed for GET requests (no SSE support)
        method_not_allowed_response
      else
        # Return 405 for any other HTTP method
        method_not_allowed_response
      end
    end

    def handle_post_request(request)
      @logger.debug("Received POST request to MCP endpoint")

      begin
        # Read and parse the request body
        body = request.body.read
        message = JSON.parse(body)

        @logger.debug("Processing message: #{message.inspect}")

        # Validate JSON-RPC 2.0 format
        unless valid_jsonrpc_message?(message)
          return json_rpc_error_response(400, -32600, "Invalid Request", nil)
        end

        # Process the message through FastMCP's server
        response = @server.process_message(message)

        @logger.debug("Sending response: #{response.inspect}")

        # Return the response as JSON
        [
          200,
          { "Content-Type" => "application/json" },
          [ JSON.generate(response) ]
        ]
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

      # Must have either a method (request/notification) or result/error (response)
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
