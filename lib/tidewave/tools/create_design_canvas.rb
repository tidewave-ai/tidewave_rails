# frozen_string_literal: true

require "fileutils"
require "json"
require "net/http"
require "pathname"
require "uri"

class Tidewave::Tools::CreateDesignCanvas < Tidewave::Tool
  class Error < StandardError; end

  DESCRIPTION = <<~DESCRIPTION.freeze
    Creates a new design canvas, an HTML file for presenting design explorations.

    The tool returns the absolute path of the HTML file. The file includes usage
    instructions, read it, then edit it to author the actual design.
  DESCRIPTION

  FETCH_TIMEOUT_SECONDS = 15

  def initialize(options = {})
    super
    @client_url = options[:client_url]
  end

  def browser_tool?
    true
  end

  def definition
    {
      "name" => "create_design_canvas",
      "description" => DESCRIPTION,
      "inputSchema" => {
        "type" => "object",
        "properties" => {
          "path" => {
            "type" => "string",
            "description" =>
              "The absolute path for the canvas file, with .html file extension. The file must not exist yet."
          }
        },
        "required" => [ "path" ]
      }
    }
  end

  def call(arguments)
    path = arguments.fetch("path")

    unless Pathname.new(path).absolute? && path.end_with?(".html")
      return error_result("Invalid path #{path.inspect}. It must be an absolute path with the .html file extension.")
    end

    html = fetch_canvas_html
    write_canvas(path, html)

    "Design canvas created at: <path>#{path}</path>. Read the file for usage instructions."
  rescue Error => error
    error_result(error.message)
  end

  private

  def write_canvas(path, html)
    begin
      FileUtils.mkdir_p(File.dirname(path))
    rescue SystemCallError => error
      raise Error, "Failed to create the design canvas directory: #{error.message}"
    end

    File.write(path, html, mode: "wx")
  rescue Errno::EEXIST
    raise Error, "Failed to create the design canvas file, the file already exists."
  rescue SystemCallError => error
    raise Error, "Failed to create the design canvas file: #{error.message}"
  end

  def fetch_canvas_html
    url = @client_url.to_s.sub(%r{/\z}, "") + "/tc/data/canvas.json"
    uri = URI.parse(url)

    response =
      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: FETCH_TIMEOUT_SECONDS,
        read_timeout: FETCH_TIMEOUT_SECONDS
      ) { |http| http.request(Net::HTTP::Get.new(uri)) }

    unless response.is_a?(Net::HTTPOK)
      raise Error, "Failed to fetch the design canvas template, request to #{url} failed with status #{response.code}"
    end

    parse_canvas_html(response.body, url)
  rescue SystemCallError, SocketError, IOError, Timeout::Error, OpenSSL::SSL::SSLError => error
    raise Error, "Failed to fetch the design canvas template, request to #{url} failed: #{error.message}"
  end

  def parse_canvas_html(body, url)
    payload =
      begin
        JSON.parse(body)
      rescue JSON::ParserError
        nil
      end

    html = payload["html"] if payload.is_a?(Hash)

    unless html.is_a?(String)
      raise Error, "Failed to fetch the design canvas template, unexpected response from #{url}"
    end

    html
  end

  def error_result(text)
    {
      "content" => [ { "type" => "text", "text" => text } ],
      "isError" => true
    }
  end
end
