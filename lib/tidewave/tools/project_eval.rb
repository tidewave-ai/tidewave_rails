# frozen_string_literal: true

class Tidewave::Tools::ProjectEval < Tidewave::Tools::Base
  tool_name "project_eval"
  description <<~DESCRIPTION
    Evaluates Ruby code in the context of the project.

    The current Ruby version is: #{RUBY_VERSION}

    Use this tool every time you need to evaluate Ruby code,
    including to test the behaviour of a function or to debug
    something. The tool also returns anything written to standard
    output. DO NOT use shell tools to evaluate Ruby code.
  DESCRIPTION

  arguments do
    required(:code).filled(:string).description("The Ruby code to evaluate")
  end

  def call(code:)
    original_stdout = $stdout
    original_stderr = $stderr

    stdout_capture = StringIO.new
    stderr_capture = StringIO.new
    $stdout = stdout_capture
    $stderr = stderr_capture

    begin
      result = eval(code)
      stdout = stdout_capture.string
      stderr = stderr_capture.string

      if stdout.empty? && stderr.empty?
        # We explicitly call to_s so the result is not accidentally
        # parsed as a JSON response by FastMCP.
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
end
