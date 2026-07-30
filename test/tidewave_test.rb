# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "rack/deflater"
require "zlib"

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

  def test_connect_route_returns_control_app_with_content_security_policy
    status, headers, body = perform_request(@app, path: "/tidewave/connect")

    assert_equal 200, status
    assert_equal "text/html", headers["content-type"]
    assert_equal "base-uri 'self'; frame-ancestors 'self';", headers["content-security-policy"]
    assert_includes body, "https://tidewave.ai/tc/control.js"
    refute_includes body, "/tc/tc.js"

    meta_content = body[/name="tidewave:config" content="([^"]*)"/, 1]
    payload = JSON.parse(CGI.unescapeHTML(meta_content))
    assert_equal "test-app", payload.dig("tidewave", "project_name")
    assert payload.key?("root")
    assert payload.key?("framework")
  end

  def test_injects_toolbar_into_html_responses
    downstream = lambda do |_env|
      body = "<html><head><title>Demo</title></head><body>Hello</body></html>"
      headers = {
        "content-type" => "text/html; charset=utf-8",
        "content-length" => body.bytesize.to_s,
        "etag" => '"original"'
      }
      [ 200, headers, [ body ] ]
    end
    app = Tidewave.new(
      downstream,
      allow_remote_access: true,
      client_url: "http://localhost:4000",
      project_name: "demo-app",
      root: @tmpdir
    )

    _status, headers, body = perform_request(
      app,
      path: "/",
      puma_socket: fake_socket(port: 5000)
    )

    assert_includes body, 'name="tidewave:config"'
    assert_includes body, "http://localhost:4000/tc/toolbar.js"
    assert_operator body.index("/tc/toolbar.js"), :<, body.downcase.index("</head>")
    refute headers.key?("content-length")
    refute headers.key?("etag")

    payload = JSON.parse(CGI.unescapeHTML(body[/name="tidewave:config" content="([^"]+)"/, 1]))
    assert_equal "demo-app", payload.dig("tidewave", "project_name")
    assert_equal 5000, payload.dig("tidewave", "local_port")
    assert_equal @tmpdir, payload["root"]
    assert_equal({}, payload["framework"])
  end

  def test_toolbar_config_includes_the_wsl_distribution_at_the_top_level
    previous_wsl_distro = ENV["WSL_DISTRO_NAME"]
    ENV["WSL_DISTRO_NAME"] = "Ubuntu-24.04"
    downstream = ->(_env) { [ 200, { "content-type" => "text/html" }, [ "<head></head>" ] ] }
    app = Tidewave.new(downstream, allow_remote_access: true, project_name: "demo-app")

    _status, _headers, body = perform_request(app, path: "/")
    payload = JSON.parse(CGI.unescapeHTML(body[/name="tidewave:config" content="([^"]+)"/, 1]))

    assert_equal "Ubuntu-24.04", payload["wsl_distro"]
    refute payload["tidewave"].key?("wsl_distro")
  ensure
    ENV["WSL_DISTRO_NAME"] = previous_wsl_distro
  end

  def test_injects_toolbar_without_inspecting_request_headers
    downstream = ->(_env) { [ 200, { "content-type" => "text/html" }, [ "<head></head>" ] ] }
    app = Tidewave.new(downstream, allow_remote_access: true, project_name: "demo-app")

    _status, _headers, body = perform_request(app, path: "/")

    assert_includes body, "/tc/toolbar.js"
  end

  def test_does_not_inject_toolbar_when_disabled
    downstream = ->(_env) { [ 200, { "content-type" => "text/html" }, [ "<head></head>" ] ] }
    app = Tidewave.new(downstream, allow_remote_access: true, project_name: "demo-app", toolbar: false)

    _status, _headers, body = perform_request(app, path: "/")

    refute_includes body, "/tc/toolbar.js"
  end

  def test_does_not_inject_toolbar_into_non_html_or_encoded_responses
    html = "<head></head>"

    [
      [ "text/plain", nil ],
      [ "text/html", "gzip" ],
      [ "text/html", "deflate" ],
      [ "text/html", "br" ],
      [ "text/html", "zstd" ],
      [ "text/html", "identity, gzip" ]
    ].each do |content_type, content_encoding|
      headers = { "content-type" => content_type, "content-length" => html.bytesize.to_s, "etag" => '"original"' }
      headers["content-encoding"] = content_encoding if content_encoding
      downstream = ->(_env) { [ 200, headers, [ html ] ] }
      app = Tidewave.new(downstream, allow_remote_access: true, project_name: "demo-app")

      _status, response_headers, body = perform_request(app, path: "/")

      refute_includes body, "/tc/toolbar.js"
      assert_equal html.bytesize.to_s, response_headers["content-length"]
      assert_equal '"original"', response_headers["etag"]
    end
  end

  def test_injects_toolbar_for_identity_encoded_responses_and_rack_2_header_names
    headers = {
      "Content-Type" => "text/html",
      "Content-Encoding" => " Identity ",
      "Content-Length" => "13",
      "ETag" => '"original"'
    }
    downstream = ->(_env) { [ 200, headers, [ "<head></head>" ] ] }
    app = Tidewave.new(downstream, allow_remote_access: true, project_name: "demo-app")

    _status, response_headers, body = perform_request(app, path: "/")

    assert_includes body, "/tc/toolbar.js"
    refute response_headers.keys.any? { |header| header.downcase == "content-length" }
    refute response_headers.keys.any? { |header| header.downcase == "etag" }
    assert_equal " Identity ", response_headers["Content-Encoding"]
  end

  def test_warns_once_when_encoded_html_prevents_toolbar_injection
    warnings = []
    logger = Struct.new(:warnings) do
      def warn(message)
        warnings << message
      end
    end.new(warnings)
    headers = { "content-type" => "text/html", "content-encoding" => "gzip" }
    downstream = ->(_env) { [ 200, headers, [ "encoded" ] ] }
    app = Tidewave.new(
      downstream,
      allow_remote_access: true,
      logger: logger,
      project_name: "demo-app"
    )

    2.times { perform_request(app, path: "/") }

    assert_equal [ Tidewave::ENCODED_HTML_WARNING ], warnings
    assert_includes warnings.first, "Rack::Deflater"
  end

  def test_defers_body_consumption_and_injects_across_chunks
    body_class = Class.new do
      attr_reader :each_called, :closed

      def each
        @each_called = true
        yield "<html><he"
        yield "ad><title>Demo</title></he"
        yield "ad><body>Hello</body></html>"
      end

      def close
        @closed = true
      end
    end
    original_body = body_class.new
    downstream = lambda do |_env|
      [ 200, { "content-type" => "text/html", "content-length" => "62", "etag" => '"original"' }, original_body ]
    end
    app = Tidewave.new(downstream, allow_remote_access: true, project_name: "demo-app")
    env = Rack::MockRequest.env_for("/")

    _status, headers, response_body = app.call(env)

    refute original_body.each_called
    refute original_body.closed
    refute headers.key?("content-length")
    refute headers.key?("etag")

    body = collect_body(response_body)

    assert original_body.each_called
    assert original_body.closed
    assert_includes body, "<title>Demo</title>"
    assert_includes body, "/tc/toolbar.js"
    assert_operator body.index("/tc/toolbar.js"), :<, body.downcase.index("</head>")
  end

  def test_preserves_html_without_a_closing_head
    html = "<html><body>Hello</body></html>"
    downstream = ->(_env) { [ 200, { "content-type" => "text/html" }, [ html ] ] }
    app = Tidewave.new(downstream, allow_remote_access: true, project_name: "demo-app")

    _status, _headers, body = perform_request(app, path: "/")

    assert_equal html, body
  end

  def test_deflater_compresses_after_toolbar_injection
    html = "<html><head></head><body>Hello</body></html>"
    downstream = ->(_env) { [ 200, { "content-type" => "text/html" }, [ html ] ] }
    tidewave = Tidewave.new(downstream, allow_remote_access: true, project_name: "demo-app")
    app = Rack::Deflater.new(tidewave)

    _status, headers, body = perform_request(app, path: "/", accept_encoding: "gzip")

    assert_equal "gzip", headers["content-encoding"]
    assert_includes gunzip(body), "/tc/toolbar.js"
  end

  def test_skips_toolbar_when_deflater_compresses_before_injection
    html = "<html><head></head><body>Hello</body></html>"
    downstream = ->(_env) { [ 200, { "content-type" => "text/html" }, [ html ] ] }
    compressed_app = Rack::Deflater.new(downstream)
    app = Tidewave.new(compressed_app, allow_remote_access: true, project_name: "demo-app")

    _status, headers, body = perform_request(app, path: "/", accept_encoding: "gzip")

    assert_equal "gzip", headers["content-encoding"]
    refute_includes gunzip(body), "/tc/toolbar.js"
  end

  def test_closes_the_original_body
    body_class = Class.new do
      attr_reader :closed

      def each
        yield "<head></head>"
      end

      def close
        @closed = true
      end
    end
    original_body = body_class.new
    downstream = ->(_env) { [ 200, { "content-type" => "text/html" }, original_body ] }
    app = Tidewave.new(downstream, allow_remote_access: true, project_name: "demo-app")

    _status, _headers, body = perform_request(app, path: "/")

    assert_includes body, "/tc/toolbar.js"
    assert original_body.closed
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
    status, _headers, _body = perform_request(
      @app,
      path: "/tidewave/other",
      origin: "http://example.org"
    )
    assert_equal 403, status

    # Even same-origin browser requests are refused
    status, _headers, _body = perform_request(
      @app,
      path: "/tidewave/mcp",
      method: "POST",
      origin: "http://example.org",
      host: "example.org",
      body: JSON.generate({ jsonrpc: "2.0", method: "ping", id: 1 })
    )
    assert_equal 403, status
  end

  def test_config_allows_cross_site_requests_with_cors
    status, headers, body = perform_request(
      @app,
      path: "/tidewave/config",
      fetch_site: "cross-site",
      fetch_mode: "cors"
    )

    assert_equal 200, status
    assert_equal "*", headers["access-control-allow-origin"]
    assert_includes body, "\"tidewave_version\""
  end

  def test_home_page_allows_any_cross_site_requests
    # Including embedding in a cross-origin iframe
    status, _headers, _body = perform_request(
      @app,
      path: "/tidewave",
      fetch_site: "cross-site",
      fetch_mode: "navigate",
      fetch_dest: "iframe"
    )
    assert_equal 200, status
  end

  def test_pages_allow_cross_site_navigations
    status, _headers, _body = perform_request(
      @app,
      path: "/tidewave/connect",
      fetch_site: "cross-site",
      fetch_mode: "navigate",
      fetch_dest: "document"
    )
    assert_equal 200, status
  end

  def test_upload_endpoint_accepts_same_origin_requests
    status, headers, body = perform_multipart_upload(
      @app,
      type: "screenshot",
      filename: "capture.png",
      content_type: "image/png",
      content: valid_png,
      fetch_site: "same-origin"
    )

    expected_path = File.join(@tmpdir, "tmp", "tidewave", "screenshots", "capture.png")
    expected_response_path = File.join("tmp", "tidewave", "screenshots", "capture.png")

    assert_equal 200, status
    assert_equal "application/json", headers["content-type"]
    assert_equal({ "status" => "ok", "path" => expected_response_path }, JSON.parse(body))
    assert_equal valid_png, File.binread(expected_path)
  end

  def test_upload_endpoint_rejects_cross_site_requests
    status, _headers, body = perform_multipart_upload(
      @app,
      type: "screenshot",
      filename: "capture.png",
      content_type: "image/png",
      content: valid_png,
      fetch_site: "cross-site"
    )

    assert_equal 403, status
    assert_includes body, "same origin"
  end

  def test_upload_endpoint_rejects_same_site_requests
    # Same-site is still a different origin (such as another subdomain
    # or port)
    status, _headers, _body = perform_request(
      @app,
      path: "/tidewave/upload",
      method: "POST",
      fetch_site: "same-site",
      fetch_mode: "cors"
    )

    assert_equal 403, status
  end

  def test_upload_endpoint_rejects_cross_site_form_submissions
    # Form submissions are navigations, but only GET navigations may
    # cross sites
    status, _headers, _body = perform_request(
      @app,
      path: "/tidewave/upload",
      method: "POST",
      fetch_site: "cross-site",
      fetch_mode: "navigate",
      fetch_dest: "document"
    )

    assert_equal 403, status
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
    expected_response_path = File.join("tmp", "tidewave", "recordings", "capture.webm")

    assert_equal 200, status
    assert_equal({ "status" => "ok", "path" => expected_response_path }, JSON.parse(body))
    assert_equal valid_webm, File.binread(expected_path)
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

  def test_requests_without_fetch_metadata_are_allowed
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

  def perform_multipart_upload(app, type:, filename:, content_type:, content:, fetch_site: nil, host: "example.test")
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
      fetch_site: fetch_site,
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

  def perform_request(app, path:, method: "GET", body: nil, remote_addr: "127.0.0.1", origin: nil, fetch_site: nil, fetch_mode: nil, fetch_dest: nil, forwarded_for: nil, host: nil, server_port: nil, puma_socket: nil, content_type: nil, accept_encoding: nil)
    env = Rack::MockRequest.env_for(path,
      method: method,
      input: body.to_s,
      "REMOTE_ADDR" => remote_addr)

    env["CONTENT_TYPE"] = content_type if content_type
    env["HTTP_ORIGIN"] = origin if origin
    env["HTTP_SEC_FETCH_SITE"] = fetch_site if fetch_site
    env["HTTP_SEC_FETCH_MODE"] = fetch_mode if fetch_mode
    env["HTTP_SEC_FETCH_DEST"] = fetch_dest if fetch_dest
    env["HTTP_X_FORWARDED_FOR"] = forwarded_for if forwarded_for
    env["HTTP_HOST"] = host if host
    env["SERVER_PORT"] = server_port if server_port
    env["puma.socket"] = puma_socket if puma_socket
    env["HTTP_ACCEPT_ENCODING"] = accept_encoding if accept_encoding

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

  def gunzip(body)
    Zlib::GzipReader.new(StringIO.new(body)).read
  end
end
