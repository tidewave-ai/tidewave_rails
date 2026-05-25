# frozen_string_literal: true

require "json"
require "stringio"
require "timeout"

class Tidewave::Tools::ProjectEval < Tidewave::Tool
  DESCRIPTION = <<~DESCRIPTION.freeze
    Evaluates Ruby code in the context of the project.

    The current Ruby version is: #{RUBY_VERSION}

    Use this tool every time you need to evaluate Ruby code,
    including to test the behaviour of a function or to debug
    something. The tool also returns anything written to standard
    output. DO NOT use shell tools to evaluate Ruby code.
  DESCRIPTION

  DEFAULT_TIMEOUT = 30_000

  def definition
    {
      "name" => "project_eval",
      "description" => DESCRIPTION,
      "inputSchema" => {
        "type" => "object",
        "properties" => {
          "arguments" => {
            "description" => "The arguments to pass to evaluation. They are available inside the evaluated code as `arguments`.",
            "items" => {},
            "type" => "array"
          },
          "code" => {
            "description" => "The Ruby code to evaluate",
            "type" => "string",
            "minLength" => 1
          },
          "timeout" => {
            "description" => "The timeout in milliseconds. If the evaluation takes longer than this, it will be terminated. Defaults to 30000 (30 seconds).",
            "type" => "integer",
            "not" => {
              "type" => "null"
            }
          }
        },
        "required" => [ "code" ]
      }
    }
  end

  def call(arguments_hash)
    code = arguments_hash.fetch("code")
    arguments = arguments_hash.fetch("arguments", [])
    timeout = arguments_hash.fetch("timeout", DEFAULT_TIMEOUT)
    json = arguments_hash.fetch("json", false)

    original_stdout = $stdout
    original_stderr = $stderr

    stdout_capture = StringIO.new
    stderr_capture = StringIO.new
    $stdout = stdout_capture
    $stderr = stderr_capture

    begin
      timeout_seconds = timeout / 1000.0

      success, result = begin
        Timeout.timeout(timeout_seconds) do
          [ true, eval(code, eval_binding(arguments)) ]
        end
      rescue Timeout::Error
        [ false, "Timeout::Error: Evaluation timed out after #{timeout} milliseconds." ]
      rescue => e
        [ false, e.full_message ]
      end

      stdout = stdout_capture.string
      stderr = stderr_capture.string

      if json
        JSON.generate({
          "result" => result,
          "success" => success,
          "stdout" => stdout,
          "stderr" => stderr
        })
      elsif stdout.empty? && stderr.empty?
        result.to_s
      else
        <<~OUTPUT
          STDOUT:

          #{stdout}

          STDERR:

          #{stderr}

          Result:

          #{result}
        OUTPUT
      end
    ensure
      $stdout = original_stdout
      $stderr = original_stderr
    end
  end

  private

  def eval_binding(arguments)
    binding
  end
end
