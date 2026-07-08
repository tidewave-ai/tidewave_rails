# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class TidewaveTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("tidewave-test")
    @downstream_calls = []
    @downstream_app = lambda do |env|
      @downstream_calls << env
      [ 200, { "content-type" => "text/plain", "x-frame-options" => "DENY" }, [ "demo response" ] ]
    end

    @app = Tidewave.new(
      @downstream_app,
      allow_remote_access: true,
      allowed_origins: [ "example.test" ],
      project_name: "test-app",
      root: @tmpdir
    )
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if @tmpdir && File.directory?(@tmpdir)
  end

  def test_non_tidewave_route_passes_through
    status, headers, body = perform_request(@app, path: "/")

    assert_equal 200, status
    assert_equal "text/plain", headers["content-type"]
    assert_equal "demo response", body
    assert_equal 1, @downstream_calls.length
  end

  def test_non_tidewave_route_strips_x_frame_options
    status, headers, _body = perform_request(@app, path: "/")

    assert_equal 200, status
    assert_nil headers["x-frame-options"]
  end

  def test_home_route_returns_html
    status, headers, body = perform_request(@app, path: "/tidewave")

    assert_equal 200, status
    assert_equal "text/html", headers["content-type"]
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
    assert_equal "application/json", headers["content-type"]
    assert_includes body, "\"tidewave_version\""
  end

  def test_local_ip_detection
    app = Tidewave.new(@downstream_app, allow_remote_access: false, project_name: "test-app")

    [ "127.0.0.1", "127.0.0.2", "127.0.0.255", "::1", "::ffff:127.0.0.1" ].each do |ip|
      status, headers, body = perform_request(app, path: "/tidewave/config", remote_addr: ip)

      assert_equal 200, status, "expected #{ip} to be accepted as a loopback address"
      assert_equal "application/json", headers["content-type"]
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

    status, headers, body = perform_request(
      app,
      path: "/tidewave/config",
      host: "example.test:3000",
      server_port: "4000",
      puma_socket: fake_socket(port: 5000)
    )

    assert_equal 200, status
    assert_equal "application/json", headers["content-type"]
    assert_equal "*", headers["access-control-allow-origin"]

    payload = JSON.parse(body)
    assert_equal "rack", payload["framework_type"]
    assert_nil payload["orm_adapter"]
    assert_equal Tidewave::VERSION, payload["tidewave_version"]
    assert_equal({ "id" => "dashbit" }, payload["team"])
    assert_equal "demo-app", payload["project_name"]
    assert_equal 5000, payload["local_port"]
    assert_equal "tmp", payload["tmp_dir"]
  end

  def test_config_endpoint_returns_configured_tmp_dir
    app = Tidewave.new(
      @downstream_app,
      allow_remote_access: true,
      project_name: "demo-app",
      tmp_dir: "custom-tmp"
    )

    _status, _headers, body = perform_request(app, path: "/tidewave/config")

    assert_equal "custom-tmp", JSON.parse(body)["tmp_dir"]
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

  def test_config_endpoint_returns_nil_local_port_for_missing_invalid_or_zero_puma_socket_port
    app = Tidewave.new(@downstream_app, allow_remote_access: true, project_name: "demo-app")

    [ nil, fake_socket(port: nil, ip: false) ].each do |puma_socket|
      _status, _headers, body = perform_request(app, path: "/tidewave/config", puma_socket: puma_socket)

      assert_nil JSON.parse(body)["local_port"]
    end
  end

  def test_config_endpoint_reads_local_port_from_socket_io_fallback
    app = Tidewave.new(@downstream_app, allow_remote_access: true, project_name: "demo-app")

    _status, _headers, body = perform_request(
      app,
      path: "/tidewave/config",
      puma_socket: fake_socket(port: 5001, direct_local_address: false)
    )

    assert_equal 5001, JSON.parse(body)["local_port"]
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

  def test_mcp_and_unmatched_tidewave_routes_refuse_requests_with_origin_header
    status, _headers, _body = perform_request(@app, path: "/tidewave/other", origin: "http://localhost:4001")
    assert_equal 403, status

    status, _headers, _body = perform_request(
      @app,
      path: "/tidewave/mcp",
      method: "POST",
      origin: "http://localhost:4001",
      body: JSON.generate({ jsonrpc: "2.0", method: "ping", id: 1 })
    )
    assert_equal 403, status
  end

  def test_config_allows_requests_with_origin_header_and_cors
    status, headers, body = perform_request(@app, path: "/tidewave/config", origin: "http://localhost:4001")

    assert_equal 200, status
    assert_equal "*", headers["access-control-allow-origin"]
    assert_includes body, "\"tidewave_version\""
  end

  def test_root_allows_any_origin
    status, _headers, _body = perform_request(@app, path: "/tidewave", origin: "http://example.com")
    assert_equal 200, status

    status, _headers, _body = perform_request(@app, path: "/tidewave", origin: "http://localhost:4000")
    assert_equal 200, status
  end

  def test_upload_endpoint_accepts_valid_screenshot_from_same_origin
    status, headers, body = perform_multipart_upload(
      @app,
      type: "screenshot",
      filename: "capture.png",
      content_type: "image/png",
      content: valid_png,
      origin: "http://example.test:3000",
      host: "example.test:3000"
    )

    expected_path = File.join(@tmpdir, "tmp", "tidewave", "screenshots", "capture.png")

    assert_equal 200, status
    assert_equal "application/json", headers["content-type"]
    assert_equal({ "status" => "ok", "path" => expected_path }, JSON.parse(body))
    assert_equal valid_png, File.binread(expected_path)
  end

  def test_upload_endpoint_accepts_valid_recording_without_origin
    status, _headers, body = perform_multipart_upload(
      @app,
      type: "recording",
      filename: "capture.webm",
      content_type: "video/webm;codecs=vp9",
      content: valid_webm
    )

    expected_path = File.join(@tmpdir, "tmp", "tidewave", "recordings", "capture.webm")

    assert_equal 200, status
    assert_equal({ "status" => "ok", "path" => expected_path }, JSON.parse(body))
    assert_equal valid_webm, File.binread(expected_path)
  end

  def test_upload_endpoint_uses_configured_tmp_dir
    app = Tidewave.new(
      @downstream_app,
      allow_remote_access: true,
      project_name: "test-app",
      root: @tmpdir,
      tmp_dir: "custom-tmp"
    )

    status, _headers, body = perform_multipart_upload(
      app,
      type: "screenshot",
      filename: "capture.png",
      content_type: "image/png",
      content: valid_png
    )

    expected_path = File.join(@tmpdir, "custom-tmp", "tidewave", "screenshots", "capture.png")

    assert_equal 200, status
    assert_equal({ "status" => "ok", "path" => expected_path }, JSON.parse(body))
    assert_equal valid_png, File.binread(expected_path)
  end

  def test_upload_endpoint_rejects_invalid_type_or_content_type
    [
      { type: "other", filename: "capture.png", content_type: "image/png" },
      { type: "screenshot", filename: "capture.txt", content_type: "text/plain" }
    ].each do |upload|
      status, _headers, body = perform_multipart_upload(@app, **upload, content: valid_png)

      assert_equal 400, status
      assert_equal Tidewave::INVALID_UPLOAD, body
    end
  end

  def test_upload_endpoint_rejects_invalid_file_magic_bytes
    status, _headers, body = perform_multipart_upload(
      @app,
      type: "screenshot",
      filename: "capture.png",
      content_type: "image/png",
      content: "not an image"
    )

    assert_equal 400, status
    assert_equal Tidewave::INVALID_UPLOAD, body
  end

  def test_upload_endpoint_rejects_invalid_filenames
    [
      "capture png.jpg",
      "capture.gif",
      "..capture.png"
    ].each do |filename|
      status, _headers, body = perform_multipart_upload(
        @app,
        type: "screenshot",
        filename: filename,
        content_type: "image/jpeg",
        content: valid_jpg
      )

      assert_equal 400, status
      assert_equal Tidewave::INVALID_UPLOAD, body
    end
  end

  def test_upload_endpoint_rejects_cross_origin_requests
    status, _headers, body = perform_multipart_upload(
      @app,
      type: "screenshot",
      filename: "capture.png",
      content_type: "image/png",
      content: valid_png,
      origin: "http://evil.test:3000",
      host: "example.test:3000"
    )

    assert_equal 403, status
    assert_equal Tidewave::INVALID_UPLOAD_ORIGIN, body
  end

  def test_upload_endpoint_does_not_trust_host_header_for_origin_check
    status, _headers, body = perform_multipart_upload(
      @app,
      type: "screenshot",
      filename: "capture.png",
      content_type: "image/png",
      content: valid_png,
      origin: "http://evil.test:3000",
      host: "evil.test:3000"
    )

    assert_equal 403, status
    assert_equal Tidewave::INVALID_UPLOAD_ORIGIN, body
  end

  def test_upload_endpoint_accepts_configured_origin_with_different_port
    app = Tidewave.new(
      @downstream_app,
      allow_remote_access: true,
      allowed_origins: [ "http://example.test:4000" ],
      project_name: "test-app",
      root: @tmpdir
    )

    status, _headers, body = perform_multipart_upload(
      app,
      type: "screenshot",
      filename: "capture.png",
      content_type: "image/png",
      content: valid_png,
      origin: "http://example.test:3000",
      host: "evil.test:3000"
    )

    expected_path = File.join(@tmpdir, "tmp", "tidewave", "screenshots", "capture.png")

    assert_equal 200, status
    assert_equal({ "status" => "ok", "path" => expected_path }, JSON.parse(body))
  end

  def test_no_origin_header_allowed
    status, headers, body = perform_request(@app, path: "/tidewave/config")

    assert_equal 200, status
    assert_equal "application/json", headers["content-type"]
    assert_includes body, "\"tidewave_version\""
  end

  def test_trailing_slash_maps_to_home_route
    status, _headers, body = perform_request(@app, path: "/tidewave/")

    assert_equal 200, status
    refute_equal "demo response", body
  end

  def test_logs_security_rejections
    warnings = []
    logger = Struct.new(:warnings) do
      def warn(message)
        warnings << message
      end
    end.new(warnings)
    app = Tidewave.new(@downstream_app, allow_remote_access: false, project_name: "test-app", logger: logger)

    status, _headers, _body = perform_request(app, path: "/tidewave/config", remote_addr: "192.168.1.100")

    assert_equal 403, status
    assert_equal [ Tidewave::INVALID_IP ], warnings
  end

  private

  def perform_multipart_upload(app, type:, filename:, content_type:, content:, origin: nil, host: "example.test")
    body, request_content_type = multipart_body(
      type: type,
      filename: filename,
      content_type: content_type,
      content: content
    )

    perform_request(
      app,
      path: "/tidewave/upload",
      method: "POST",
      body: body,
      content_type: request_content_type,
      origin: origin,
      host: host
    )
  end

  def multipart_body(type:, filename:, content_type:, content:)
    boundary = "----tidewave-test-boundary"
    body = +"".b
    body << "--#{boundary}\r\n"
    body << "Content-Disposition: form-data; name=\"type\"\r\n\r\n"
    body << "#{type}\r\n"
    body << "--#{boundary}\r\n"
    body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"\r\n"
    body << "Content-Type: #{content_type}\r\n\r\n"
    body << content
    body << "\r\n--#{boundary}--\r\n"

    [ body, "multipart/form-data; boundary=#{boundary}" ]
  end

  def valid_jpg
    "\xFF\xD8\xFF\xE0JFIF\xFF\xD9".b
  end

  def valid_png
    "\x89PNG\r\n\x1A\nDATA".b
  end

  def valid_webm
    "\x1A\x45\xDF\xA3\x42\x82webmDATA".b
  end

  def perform_request(app, path:, method: "GET", body: nil, remote_addr: "127.0.0.1", origin: nil, forwarded_for: nil, host: nil, server_port: nil, puma_socket: nil, content_type: nil)
    env = Rack::MockRequest.env_for(path,
      method: method,
      input: body.to_s,
      "REMOTE_ADDR" => remote_addr)

    env["CONTENT_TYPE"] = content_type if content_type
    env["HTTP_ORIGIN"] = origin if origin
    env["HTTP_X_FORWARDED_FOR"] = forwarded_for if forwarded_for
    env["HTTP_HOST"] = host if host
    env["SERVER_PORT"] = server_port if server_port
    env["puma.socket"] = puma_socket if puma_socket

    status, headers, response = app.call(env)
    [ status, headers, collect_body(response) ]
  end

  def fake_socket(port:, ip: true, direct_local_address: true)
    addr = Struct.new(:port, :ip) do
      def ip?
        ip
      end

      def ip_port
        port
      end
    end.new(port, ip)

    if direct_local_address
      Struct.new(:addr) do
        def local_address
          addr
        end
      end.new(addr)
    else
      Struct.new(:addr) do
        def to_io
          Struct.new(:addr) do
            def local_address
              addr
            end
          end.new(addr)
        end
      end.new(addr)
    end
  end

  def collect_body(response)
    body = +""
    response.each { |part| body << part }
    response.close if response.respond_to?(:close)
    body
  end
end
