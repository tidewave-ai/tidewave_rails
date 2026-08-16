# frozen_string_literal: true

require "test_helper"
require "socket"
require "tmpdir"

class TidewaveCreateDesignCanvasTest < Minitest::Test
  CANVAS_HTML = "<!doctype html>\n<html>canvas</html>"

  def test_definition_returns_the_tool_definition
    definition = tool("http://example.test").definition

    assert_equal "create_design_canvas", definition["name"]
    assert_equal [ "path" ], definition["inputSchema"]["required"]
  end

  def test_is_a_browser_tool
    assert_predicate tool("http://example.test"), :browser_tool?
  end

  def test_creates_the_canvas_file_including_parent_directories
    with_canvas_server do |client_url|
      Dir.mktmpdir do |tmp_dir|
        path = File.join(tmp_dir, "designs", "canvas.html")

        result = tool(client_url).validate_and_call({ "path" => path })

        assert_equal "Design canvas created at: <path>#{path}</path>. Read the file for usage instructions.", result
        assert_equal CANVAS_HTML, File.read(path)
      end
    end
  end

  def test_returns_error_for_a_relative_path
    result = tool("http://example.test").validate_and_call({ "path" => "canvas.html" })

    assert_includes error_text(result), "must be an absolute path"
  end

  def test_returns_error_for_a_path_without_html_extension
    Dir.mktmpdir do |tmp_dir|
      path = File.join(tmp_dir, "canvas.txt")

      result = tool("http://example.test").validate_and_call({ "path" => path })

      assert_includes error_text(result), "must be an absolute path with the .html file extension"
    end
  end

  def test_returns_error_when_the_file_already_exists
    with_canvas_server do |client_url|
      Dir.mktmpdir do |tmp_dir|
        path = File.join(tmp_dir, "canvas.html")
        File.write(path, "existing")

        result = tool(client_url).validate_and_call({ "path" => path })

        assert_includes error_text(result), "the file already exists"
        assert_equal "existing", File.read(path)
      end
    end
  end

  def test_returns_error_when_the_template_request_fails_with_non_200_status
    with_canvas_server(status: 404, body: "not found") do |client_url|
      Dir.mktmpdir do |tmp_dir|
        path = File.join(tmp_dir, "canvas.html")

        result = tool(client_url).validate_and_call({ "path" => path })

        assert_includes error_text(result), "Failed to fetch the design canvas template"
        refute File.exist?(path)
      end
    end
  end

  def test_returns_error_when_the_template_response_is_unexpected
    with_canvas_server(body: JSON.generate({ "unexpected" => true })) do |client_url|
      Dir.mktmpdir do |tmp_dir|
        path = File.join(tmp_dir, "canvas.html")

        result = tool(client_url).validate_and_call({ "path" => path })

        assert_includes error_text(result), "unexpected response"
        refute File.exist?(path)
      end
    end
  end

  def test_returns_error_when_the_template_server_is_unreachable
    server = TCPServer.new("127.0.0.1", 0)
    client_url = "http://127.0.0.1:#{server.addr[1]}"
    server.close

    Dir.mktmpdir do |tmp_dir|
      path = File.join(tmp_dir, "canvas.html")

      result = tool(client_url).validate_and_call({ "path" => path })

      assert_includes error_text(result), "Failed to fetch the design canvas template"
      refute File.exist?(path)
    end
  end

  private

  def tool(client_url)
    Tidewave::Tools::CreateDesignCanvas.new(client_url: client_url)
  end

  def error_text(result)
    assert result["isError"], "expected an error result, got: #{result.inspect}"
    result["content"].first["text"]
  end

  def with_canvas_server(status: 200, body: JSON.generate({ "html" => CANVAS_HTML }))
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]

    thread = Thread.new do
      loop do
        client = server.accept

        begin
          while (line = client.gets) && line != "\r\n"; end

          client.write(
            "HTTP/1.1 #{status} Status\r\n" \
            "content-type: application/json\r\n" \
            "content-length: #{body.bytesize}\r\n" \
            "connection: close\r\n" \
            "\r\n#{body}"
          )
        ensure
          client.close
        end
      end
    rescue IOError, Errno::EBADF
      # The listening socket was closed on test teardown.
    end

    yield "http://127.0.0.1:#{port}"
  ensure
    server&.close
    thread&.join(1)
  end
end
