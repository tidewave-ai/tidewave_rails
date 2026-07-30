# frozen_string_literal: true

class Tidewave::Tools::BrowserEval < Tidewave::Tool
  DESCRIPTION = <<~DESCRIPTION
    Runs JavaScript in a real browser to interact with the application.

    You MUST use "help" action first to learn the full API.
  DESCRIPTION

  BROADCAST_TIMEOUT_MS = 5_000

  def initialize(options = {})
    super
    @browser_control = options[:browser_control]
  end

  def browser_tool?
    true
  end

  def definition
    return nil unless @browser_control

    {
      "name" => "browser_eval",
      "description" => DESCRIPTION,
      "inputSchema" => {
        "type" => "object",
        "properties" => {
          "action" => {
            "type" => "string"
          },
          "sid" => {
            "description" => 'The session to target, e.g. "nice-cactus#1".',
            "type" => "string"
          },
          "args" => {
            "description" => 'Parameters for the action, as documented by "help".',
            "type" => "object",
            "additionalProperties" => true
          }
        },
        "required" => [ "action" ]
      }
    }
  end

  def call(arguments, context = {})
    url = context[:url]
    sid = arguments["sid"]

    if sid.is_a?(String) && !sid.empty?
      result = @browser_control.run(sid, "browser_eval", arguments, nil)
      direct_result(result, sid, url)
    else
      # The broadcast case is only expected to run for initial discovery.
      # We can safely retry once if the first attempt times out.
      result = @browser_control.broadcast_run("browser_eval", arguments, BROADCAST_TIMEOUT_MS)
      result = @browser_control.broadcast_run("browser_eval", arguments, BROADCAST_TIMEOUT_MS) if result == [ :error, :timeout ]
      broadcast_result(result, url)
    end
  end

  private

  def direct_result(result, sid, url)
    status, value = result
    return value.fetch("result") if status == :ok

    case value
    when :invalid_sid
      error_result(%(Invalid sid "#{sid}". A sid looks like "nice-cactus#1".))
    when :unknown_client
      error_result(
        "No connected browser owns sid \"#{sid}\". It may have disconnected — " \
        'call browser_eval({"action": "new-session"}) to start a new one.'
      )
    when :timeout
      error_result("browser_eval timed out waiting for the browser to respond.")
    when :disconnected
      error_result("The browser disconnected before responding. #{open_message(url)}")
    end
  end

  def broadcast_result(result, url)
    status, value = result
    return value.fetch("result") if status == :ok

    error_result("No browser is connected to the Tidewave control page. #{open_message(url)}")
  end

  def open_message(url)
    "Use the `open` command (or similar) to open #{url}/tidewave in the browser and try again"
  end

  def error_result(text)
    {
      "content" => [ { "type" => "text", "text" => text } ],
      "isError" => true
    }
  end
end
