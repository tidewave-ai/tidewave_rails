# frozen_string_literal: true

require "test_helper"
require "rack/lint"

# Rack::Lint is Rack's official conformance validator: it raises LintError on
# any spec violation (uppercase header keys, bad status/body shapes, etc.).
# Driving every Tidewave endpoint through it proves the middleware is Rack 3
# conformant.
class TidewaveRackLintTest < Minitest::Test
  def setup
    downstream = ->(_env) { [ 200, { "content-type" => "text/plain" }, [ "ok" ] ] }
    @app = Rack::Lint.new(Tidewave.new(downstream, project_name: "lint", allow_remote_access: true))
    @mock = Rack::MockRequest.new(@app)
    @init = JSON.generate(jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: Tidewave::PROTOCOL_VERSION })
  end

  def assert_lint_ok(&block)
    response = block.call
    assert_kind_of Integer, response.status
  rescue Rack::Lint::LintError => error
    flunk "Rack::Lint violation: #{error.message.lines.first.strip}"
  end

  def test_home_endpoint_is_rack_conformant
    assert_lint_ok { @mock.get("/tidewave") }
  end

  def test_config_endpoint_is_rack_conformant
    assert_lint_ok { @mock.get("/tidewave/config") }
  end

  def test_app_endpoint_is_rack_conformant
    assert_lint_ok { @mock.get("/tidewave/app") }
  end

  def test_toolbar_response_is_rack_conformant
    downstream = ->(_env) { [ 200, { "content-type" => "text/html" }, [ "<html><head></head></html>" ] ] }
    app = Rack::Lint.new(Tidewave.new(downstream, project_name: "lint", allow_remote_access: true))

    response = Rack::MockRequest.new(app).get("/")

    assert_includes response.body, "/tc/toolbar.js"
  end

  def test_mcp_post_is_rack_conformant
    assert_lint_ok { @mock.post("/tidewave/mcp", input: @init) }
  end

  def test_mcp_405_is_rack_conformant
    assert_lint_ok { @mock.get("/tidewave/mcp") }
    assert_lint_ok { @mock.request("DELETE", "/tidewave/mcp") }
  end

  def test_mcp_202_notification_is_rack_conformant
    assert_lint_ok { @mock.post("/tidewave/mcp", input: JSON.generate(jsonrpc: "2.0", method: "notifications/initialized")) }
  end

  def test_mcp_batch_is_rack_conformant
    assert_lint_ok { @mock.post("/tidewave/mcp", input: JSON.generate([ { jsonrpc: "2.0", id: 1, method: "ping" } ])) }
  end

  def test_mcp_error_responses_are_rack_conformant
    assert_lint_ok { @mock.post("/tidewave/mcp", input: "not json") }
  end

  def test_pass_through_is_rack_conformant
    assert_lint_ok { @mock.get("/") }
  end
end
