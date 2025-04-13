# frozen_string_literal: true

class ProjectEval < Tidewave::Tool
  tool_name "project_eval"
  description <<~DESCRIPTION
    Evaluates Ruby code in the context of the project.

    The current Ruby version is: #{RUBY_VERSION}

    The code is executed in the context of the user's project, therefore use this tool any
    time you need to evaluate code, for example to test the behavior of a function or to debug
    something. The tool also returns anything written to standard output.
  DESCRIPTION

  arguments do
    required(:code).filled(:string).description("The Ruby code to evaluate")
  end

  def call(code:)
    original_stdout = $stdout
    output_capture = StringIO.new
    $stdout = output_capture

    begin
      result = eval(code)
      stdout = output_capture.string

      if stdout.empty?
        result
      else
        {
          stdout: stdout,
          result: result
        }
      end
    ensure
      $stdout = original_stdout
    end
  end
end
