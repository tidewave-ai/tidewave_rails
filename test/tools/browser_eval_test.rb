# frozen_string_literal: true

require "test_helper"

class TidewaveBrowserEvalTest < Minitest::Test
  class FakeBrowserControl
    attr_reader :calls

    def initialize(results)
      @results = results
      @calls = []
    end

    def run(sid, tool_name, input, timeout_ms)
      @calls << [ :run, sid, tool_name, input, timeout_ms ]
      @results.shift
    end

    def broadcast_run(tool_name, input, timeout_ms)
      @calls << [ :broadcast_run, tool_name, input, timeout_ms ]
      @results.shift
    end
  end

  CONTEXT = { url: "http://localhost:3000" }.freeze

  def test_definition_requires_browser_control
    assert_nil Tidewave::Tools::BrowserEval.new({}).definition
    refute_nil tool(FakeBrowserControl.new([])).definition
  end

  def test_is_a_browser_tool
    assert_predicate tool(FakeBrowserControl.new([])), :browser_tool?
  end

  def test_sid_runs_directly_and_returns_the_browser_result
    browser_result = { "content" => [ { "type" => "text", "text" => "ok" } ], "isError" => false }
    control = FakeBrowserControl.new([ [ :ok, { "result" => browser_result } ] ])
    arguments = { "action" => "eval", "args" => { "code" => "1" }, "sid" => "nice-cactus#1" }

    result = tool(control).validate_and_call(arguments, CONTEXT)

    assert_equal browser_result, result
    assert_equal [ :run, "nice-cactus#1", "browser_eval", arguments, nil ], control.calls.first
  end

  def test_error_results_are_agent_instructive
    control = FakeBrowserControl.new([
      [ :error, :invalid_sid ],
      [ :error, :unknown_client ],
      [ :error, :timeout ],
      [ :error, :disconnected ]
    ])
    the_tool = tool(control)
    arguments = { "action" => "eval", "sid" => "nice-cactus#1" }

    assert_includes error_text(the_tool.validate_and_call(arguments.dup, CONTEXT)), "Invalid sid"
    assert_includes error_text(the_tool.validate_and_call(arguments.dup, CONTEXT)), 'browser_eval({"action": "new-session"})'
    assert_includes error_text(the_tool.validate_and_call(arguments.dup, CONTEXT)), "timed out"
    assert_includes error_text(the_tool.validate_and_call(arguments.dup, CONTEXT)), "open http://localhost:3000/tidewave in the browser"
  end

  def test_help_broadcasts_to_all_clients
    control = FakeBrowserControl.new([ [ :ok, { "result" => { "content" => [] } } ] ])

    result = tool(control).validate_and_call({ "action" => "help" }, CONTEXT)

    assert_equal({ "content" => [] }, result)
    assert_equal [ :broadcast_run, "browser_eval", { "action" => "help" }, 5_000 ], control.calls.first
  end

  def test_help_retries_the_broadcast_once_on_timeout
    control = FakeBrowserControl.new([ [ :error, :timeout ], [ :ok, { "result" => { "content" => [] } } ] ])

    result = tool(control).validate_and_call({ "action" => "help" }, CONTEXT)

    assert_equal({ "content" => [] }, result)
    assert_equal 2, control.calls.size
  end

  def test_help_timeout_suggests_opening_the_control_page
    control = FakeBrowserControl.new([ [ :error, :timeout ], [ :error, :timeout ] ])

    result = tool(control).validate_and_call({ "action" => "help" }, CONTEXT)

    assert_includes error_text(result), "No browser is connected to the Tidewave control page. Use the `open` command"
  end

  def test_actions_without_a_sid_broadcast
    control = FakeBrowserControl.new([ [ :ok, { "result" => { "content" => [] } } ] ])
    arguments = { "action" => "eval", "args" => { "code" => "1" }, "sid" => "" }

    result = tool(control).validate_and_call(arguments, CONTEXT)

    assert_equal({ "content" => [] }, result)
    assert_equal [ :broadcast_run, "browser_eval", arguments, 5_000 ], control.calls.first
  end

  private

  def tool(control)
    Tidewave::Tools::BrowserEval.new(browser_control: control)
  end

  def error_text(result)
    assert result["isError"], "expected an error result, got: #{result.inspect}"
    result["content"].first["text"]
  end
end
