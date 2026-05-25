# frozen_string_literal: true

require "test_helper"

class TidewaveMcpTest < Minitest::Test
  DEFAULT_TOOL_NAMES = %w[
    get_docs
    get_source_location
    project_eval
  ].freeze

  OPTIONAL_TOOL_NAMES = (DEFAULT_TOOL_NAMES + [ "get_logs" ]).sort.freeze

  def setup
    @downstream_app = ->(_env) { [ 200, { "Content-Type" => "text/plain" }, [ "demo response" ] ] }
    @app = Tidewave.new(@downstream_app, allow_remote_access: true, project_name: "test-app")
  end

  def test_ping_returns_jsonrpc_response
    status, headers, body = perform_request(
      @app,
      path: "/tidewave/mcp",
      method: "POST",
      body: JSON.generate({ jsonrpc: "2.0", method: "ping", id: 1 })
    )

    assert_equal 200, status
    assert_equal "application/json", headers["Content-Type"]

    payload = JSON.parse(body)
    assert_equal "2.0", payload["jsonrpc"]
    assert_equal 1, payload["id"]
    assert_equal({}, payload["result"])
  end

  def test_empty_request_body_returns_parse_error
    status, _headers, body = perform_request(@app, path: "/tidewave/mcp", method: "POST")

    assert_equal 200, status

    payload = JSON.parse(body)
    assert_equal(-32700, payload.dig("error", "code"))
    assert_equal("Parse error", payload.dig("error", "message"))
  end

  def test_invalid_json_returns_parse_error
    status, _headers, body = perform_request(@app, path: "/tidewave/mcp", method: "POST", body: "invalid json")

    assert_equal 200, status

    payload = JSON.parse(body)
    assert_equal(-32700, payload.dig("error", "code"))
    assert_equal("Parse error", payload.dig("error", "message"))
  end

  def test_invalid_jsonrpc_version_returns_invalid_request
    status, _headers, body = perform_request(
      @app,
      path: "/tidewave/mcp",
      method: "POST",
      body: JSON.generate({ jsonrpc: "1.0", method: "ping", id: 1 })
    )

    assert_equal 200, status

    payload = JSON.parse(body)
    assert_equal(-32600, payload.dig("error", "code"))
    assert_equal("Invalid JSON-RPC version", payload.dig("error", "message"))
  end

  def test_notification_returns_accepted
    status, headers, body = perform_request(
      @app,
      path: "/tidewave/mcp",
      method: "POST",
      body: JSON.generate({ jsonrpc: "2.0", method: "notifications/initialized" })
    )

    assert_equal 202, status
    assert_equal "application/json", headers["Content-Type"]
    assert_equal({ "status" => "ok" }, JSON.parse(body))
  end

  def test_initialize_requires_protocol_version
    status, _headers, body = perform_request(
      @app,
      path: "/tidewave/mcp",
      method: "POST",
      body: JSON.generate({ jsonrpc: "2.0", method: "initialize", id: 1, params: {} })
    )

    assert_equal 200, status

    payload = JSON.parse(body)
    assert_equal(-32602, payload.dig("error", "code"))
    assert_equal("Protocol version is required", payload.dig("error", "message"))
  end

  def test_initialize_returns_server_capabilities
    status, _headers, body = perform_request(
      @app,
      path: "/tidewave/mcp",
      method: "POST",
      body: JSON.generate({
        jsonrpc: "2.0",
        method: "initialize",
        id: 1,
        params: { protocolVersion: Tidewave::PROTOCOL_VERSION }
      })
    )

    assert_equal 200, status

    payload = JSON.parse(body)
    assert_equal Tidewave::PROTOCOL_VERSION, payload.dig("result", "protocolVersion")
    assert_equal false, payload.dig("result", "capabilities", "tools", "listChanged")
    assert_equal "tidewave", payload.dig("result", "serverInfo", "name")
    assert_equal Tidewave::VERSION, payload.dig("result", "serverInfo", "version")
    assert_equal DEFAULT_TOOL_NAMES, payload.dig("result", "tools").map { |tool| tool["name"] }.sort
  end

  def test_tools_list_returns_loaded_tools
    status, _headers, body = perform_request(
      @app,
      path: "/tidewave/mcp",
      method: "POST",
      body: JSON.generate({ jsonrpc: "2.0", method: "tools/list", id: 1 })
    )

    assert_equal 200, status
    tools = JSON.parse(body).dig("result", "tools")

    assert_equal DEFAULT_TOOL_NAMES, tools.map { |tool| tool["name"] }.sort
    get_source_location = tools.find { |tool| tool["name"] == "get_source_location" }
    assert_equal "Returns the source location for the given reference.\n", get_source_location["description"].lines.first
  end

  def test_tools_list_includes_get_logs_when_log_file_is_configured
    app = Tidewave.new(
      @downstream_app,
      allow_remote_access: true,
      project_name: "test-app",
      log_file: __FILE__
    )

    status, _headers, body = perform_request(
      app,
      path: "/tidewave/mcp",
      method: "POST",
      body: JSON.generate({ jsonrpc: "2.0", method: "tools/list", id: 1 })
    )

    assert_equal 200, status
    tools = JSON.parse(body).dig("result", "tools")
    assert_equal OPTIONAL_TOOL_NAMES, tools.map { |tool| tool["name"] }.sort
  end

  def test_unknown_tool_returns_method_not_found
    status, _headers, body = perform_request(
      @app,
      path: "/tidewave/mcp",
      method: "POST",
      body: JSON.generate({
        jsonrpc: "2.0",
        method: "tools/call",
        id: 1,
        params: { name: "missing", arguments: {} }
      })
    )

    assert_equal 200, status

    payload = JSON.parse(body)
    assert_equal(-32601, payload.dig("error", "code"))
    assert_equal("Tool 'missing' not found", payload.dig("error", "message"))
  end

  def test_tool_call_uses_registered_tools
    status, _headers, body = perform_request(
      @app,
      path: "/tidewave/mcp",
      method: "POST",
      body: JSON.generate({
        jsonrpc: "2.0",
        method: "tools/call",
        id: 1,
        params: { name: "project_eval", arguments: { code: "'hello'" } }
      })
    )

    assert_equal 200, status
    assert_equal "hello", JSON.parse(body).dig("result", "content", 0, "text")
  end

  private

  def perform_request(app, path:, method: "GET", body: nil, remote_addr: "127.0.0.1", origin: nil)
    env = Rack::MockRequest.env_for(path,
      method: method,
      input: body.to_s,
      "REMOTE_ADDR" => remote_addr)

    env["HTTP_ORIGIN"] = origin if origin

    status, headers, response = app.call(env)
    [ status, headers, collect_body(response) ]
  end

  def collect_body(response)
    body = +""
    response.each { |part| body << part }
    response.close if response.respond_to?(:close)
    body
  end
end

class TidewaveMcpStructuredContentTest < TidewaveActiveRecordTestCase
  def test_tool_call_includes_structured_content_for_hash_results
    app = Tidewave.new(
      ->(_env) { [ 200, { "Content-Type" => "text/plain" }, [ "demo response" ] ] },
      allow_remote_access: true,
      project_name: "test-app",
      orm_adapter: :active_record
    )

    status, _headers, body = perform_request(
      app,
      path: "/tidewave/mcp",
      method: "POST",
      body: JSON.generate({
        jsonrpc: "2.0",
        method: "tools/call",
        id: 1,
        params: { name: "execute_sql_query", arguments: { query: "SELECT 1 as id, 'example' as name" } }
      })
    )

    payload = JSON.parse(body)

    assert_equal 200, status
    assert_equal(
      {
        "columns" => [ "id", "name" ],
        "rows" => [ [ 1, "example" ] ],
        "row_count" => 1,
        "adapter" => "SQLite",
        "database" => ":memory:"
      },
      payload.dig("result", "structuredContent")
    )
    assert_equal(
      "{\"columns\":[\"id\",\"name\"],\"rows\":[[1,\"example\"]],\"row_count\":1,\"adapter\":\"SQLite\",\"database\":\":memory:\"}",
      payload.dig("result", "content", 0, "text")
    )
  end

  private

  def perform_request(app, path:, method: "GET", body: nil, remote_addr: "127.0.0.1", origin: nil)
    env = Rack::MockRequest.env_for(path,
      method: method,
      input: body.to_s,
      "REMOTE_ADDR" => remote_addr)

    env["HTTP_ORIGIN"] = origin if origin

    status, headers, response = app.call(env)
    [ status, headers, collect_body(response) ]
  end

  def collect_body(response)
    body = +""
    response.each { |part| body << part }
    response.close if response.respond_to?(:close)
    body
  end
end
