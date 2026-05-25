# frozen_string_literal: true

require "test_helper"

class TidewaveTest < Minitest::Test
  def setup
    @downstream_calls = []
    @downstream_app = lambda do |env|
      @downstream_calls << env
      [ 200, { "Content-Type" => "text/plain", "X-Frame-Options" => "DENY" }, [ "demo response" ] ]
    end

    @app = Tidewave.new(@downstream_app, allow_remote_access: true, project_name: "test-app")
  end

  def test_non_tidewave_route_passes_through
    status, headers, body = perform_request(@app, path: "/")

    assert_equal 200, status
    assert_equal "text/plain", headers["Content-Type"]
    assert_equal "demo response", body
    assert_equal 1, @downstream_calls.length
  end

  def test_non_tidewave_route_strips_x_frame_options
    status, headers, _body = perform_request(@app, path: "/")

    assert_equal 200, status
    assert_nil headers["X-Frame-Options"]
  end

  def test_home_route_returns_html
    status, headers, body = perform_request(@app, path: "/tidewave")

    assert_equal 200, status
    assert_equal "text/html", headers["Content-Type"]
    assert_includes body, "https://tidewave.ai/tc/tc.js"
    refute_includes body.downcase, "tidewave:config"
  end

  def test_unmatched_tidewave_routes_return_not_found
    status, _headers, body = perform_request(@app, path: "/tidewave/other")

    assert_equal 404, status
    assert_equal "Not Found", body
  end

  def test_security_remote_ip_blocked
    app = Tidewave.new(@downstream_app, allow_remote_access: false, project_name: "test-app")

    [ "192.168.1.100", "1.1.1.1", "invalid", "2001:4860:4860::8888" ].each do |ip|
      status, _headers, body = perform_request(app, path: "/tidewave/config", remote_addr: ip)

      assert_equal 403, status
      assert_includes body, "Tidewave does not accept remote connections by default"
    end
  end

  def test_security_remote_ip_allowed_when_enabled
    app = Tidewave.new(@downstream_app, allow_remote_access: true, project_name: "test-app")
    status, headers, body = perform_request(app, path: "/tidewave/config", remote_addr: "192.168.1.100")

    assert_equal 200, status
    assert_equal "application/json", headers["Content-Type"]
    assert_includes body, "\"tidewave_version\""
  end

  def test_local_ip_detection
    app = Tidewave.new(@downstream_app, allow_remote_access: false, project_name: "test-app")

    [ "127.0.0.1", "127.0.0.2", "127.0.0.255", "::1", "::ffff:127.0.0.1" ].each do |ip|
      status, headers, body = perform_request(app, path: "/tidewave/config", remote_addr: ip)

      assert_equal 200, status, "expected #{ip} to be accepted as a loopback address"
      assert_equal "application/json", headers["Content-Type"]
      assert_includes body, "\"tidewave_version\""
    end
  end

  def test_security_ignores_forwarded_ip_headers
    app = Tidewave.new(@downstream_app, allow_remote_access: false, project_name: "test-app")

    status, _headers, body = perform_request(
      app,
      path: "/tidewave/config",
      remote_addr: "192.168.1.100",
      forwarded_for: "127.0.0.1"
    )

    assert_equal 403, status
    assert_includes body, "Tidewave does not accept remote connections by default"
  end

  def test_config_endpoint_returns_json
    app = Tidewave.new(
      @downstream_app,
      allow_remote_access: true,
      project_name: "demo-app",
      team: { id: "dashbit" }
    )

    status, headers, body = perform_request(app, path: "/tidewave/config")

    assert_equal 200, status
    assert_equal "application/json", headers["Content-Type"]

    payload = JSON.parse(body)
    assert_equal "rack", payload["framework_type"]
    assert_nil payload["orm_adapter"]
    assert_equal Tidewave::VERSION, payload["tidewave_version"]
    assert_equal({ "id" => "dashbit" }, payload["team"])
    assert_equal "demo-app", payload["project_name"]
  end

  def test_config_endpoint_includes_orm_adapter_when_configured
    app = Tidewave.new(
      @downstream_app,
      allow_remote_access: true,
      project_name: "demo-app",
      orm_adapter: :sequel
    )

    _status, _headers, body = perform_request(app, path: "/tidewave/config")

    assert_equal "sequel", JSON.parse(body)["orm_adapter"]
  end

  def test_project_name_is_required
    error = assert_raises(ArgumentError) do
      Tidewave.new(@downstream_app, allow_remote_access: true)
    end

    assert_equal "project_name is required", error.message
  end

  def test_unmatched_tidewave_methods_return_not_found
    status, _headers, body = perform_request(@app, path: "/tidewave/config", method: "POST")

    assert_equal 404, status
    assert_equal "Not Found", body
  end

  def test_non_root_tidewave_routes_refuse_requests_with_origin_header
    status, _headers, _body = perform_request(@app, path: "/tidewave/other", origin: "http://localhost:4001")
    assert_equal 403, status

    status, _headers, _body = perform_request(@app, path: "/tidewave/config", origin: "http://localhost:4000")
    assert_equal 403, status
  end

  def test_root_allows_any_origin
    status, _headers, _body = perform_request(@app, path: "/tidewave", origin: "http://example.com")
    assert_equal 200, status

    status, _headers, _body = perform_request(@app, path: "/tidewave", origin: "http://localhost:4000")
    assert_equal 200, status
  end

  def test_no_origin_header_allowed
    status, headers, body = perform_request(@app, path: "/tidewave/config")

    assert_equal 200, status
    assert_equal "application/json", headers["Content-Type"]
    assert_includes body, "\"tidewave_version\""
  end

  def test_trailing_slash_maps_to_home_route
    status, _headers, body = perform_request(@app, path: "/tidewave/")

    assert_equal 200, status
    refute_equal "demo response", body
  end

  def test_logs_security_rejections
    logger = Minitest::Mock.new
    logger.expect(:warn, nil, [ Tidewave::INVALID_IP ])
    app = Tidewave.new(@downstream_app, allow_remote_access: false, project_name: "test-app", logger: logger)

    status, _headers, _body = perform_request(app, path: "/tidewave/config", remote_addr: "192.168.1.100")

    assert_equal 403, status
    logger.verify
  end

  private

  def perform_request(app, path:, method: "GET", body: nil, remote_addr: "127.0.0.1", origin: nil, forwarded_for: nil)
    env = Rack::MockRequest.env_for(path,
      method: method,
      input: body.to_s,
      "REMOTE_ADDR" => remote_addr)

    env["HTTP_ORIGIN"] = origin if origin
    env["HTTP_X_FORWARDED_FOR"] = forwarded_for if forwarded_for

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
