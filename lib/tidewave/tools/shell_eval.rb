# frozen_string_literal: true

require "open3"

class Tidewave::Tools::ShellEval < Tidewave::Tools::Base
  file_system_tool
  class CommandFailedError < StandardError; end

  tool_name "shell_eval"
  description <<~DESCRIPTION
    Executes a shell command in the project root directory.

    The operating system is of flavor #{RUBY_PLATFORM}.

    Avoid using this tool for file operations. Instead, rely on
    dedicated file system tools, if available.

    Do not use this tool to evaluate Ruby code. Use `project_eval` instead.
    Only use this tool if other means are not available.
  DESCRIPTION

  arguments do
    required(:command).filled(:string).description("The shell command to execute. Avoid using this for file operations; use dedicated file system tools instead.")
  end

  def call(command:)
    stdout, status = Open3.capture2e(command)
    raise CommandFailedError, "Command failed with status #{status.exitstatus}:\n\n#{stdout}" unless status.exitstatus.zero?

    stdout.strip
  end
end
