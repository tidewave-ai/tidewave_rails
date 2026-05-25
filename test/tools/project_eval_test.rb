# frozen_string_literal: true

require "test_helper"

class TidewaveProjectEvalTest < Minitest::Test
  def setup
    @tool = Tidewave::Tools::ProjectEval.new
  end

  def test_validate_and_call_returns_result_without_output
    result = @tool.validate_and_call({ "code" => "1 + 1" })

    assert_equal "2", result
  end

  def test_validate_and_call_returns_formatted_output_when_stdout_is_written
    result = @tool.validate_and_call({ "code" => "puts 'Hello, world!'" })

    assert_equal <<~OUTPUT, result
      STDOUT:

      Hello, world!


      STDERR:



      Result:


    OUTPUT
  end

  def test_validate_and_call_uses_arguments
    result = @tool.validate_and_call({
      "code" => "arguments.sum",
      "arguments" => [ 1, 2, 3 ]
    })

    assert_equal "6", result
  end

  def test_validate_and_call_respects_timeout
    result = @tool.validate_and_call({
      "code" => "sleep(1); 42",
      "timeout" => 100
    })

    assert_includes result, "Timeout::Error: Evaluation timed out after 100 milliseconds."
  end

  def test_validate_and_call_returns_error_output
    result = @tool.validate_and_call({ "code" => "raise StandardError, 'test error'" })

    assert_includes result, "test error (StandardError)"
  end

  def test_validate_and_call_returns_json_string_when_json_is_true
    result = @tool.validate_and_call({
      "code" => "arguments.map(&:upcase)",
      "arguments" => [ "hello", "world" ],
      "json" => true
    })

    assert_equal({
      "result" => [ "HELLO", "WORLD" ],
      "success" => true,
      "stdout" => "",
      "stderr" => ""
    }, JSON.parse(result))
  end
end
