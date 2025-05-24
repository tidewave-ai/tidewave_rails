# frozen_string_literal: true

require "tidewave/file_tracker"

class Tidewave::Tools::ListProjectFiles < Tidewave::Tools::Base
  tags :file_system_tool

  tool_name "list_project_files"
  description <<~DESC
    Returns a list of files in the project.

    By default, when no arguments are passed, it returns all files in the project that
    are not ignored by .gitignore.

    Optionally, a glob_pattern can be passed to filter this list. When a pattern is passed,
    the gitignore check will be skipped.
  DESC

  arguments do
    optional(:glob_pattern).maybe(:string).description('Optional: a glob pattern to filter the listed files. If a pattern is passed, the .gitignore check will be skipped.')
  end

  def call(glob_pattern: nil)
    Tidewave::FileTracker.project_files(glob_pattern: glob_pattern)
  end
end
