# frozen_string_literal: true

require "tidewave/file_tracker"

class Tidewave::Tools::GlobProjectFiles < Tidewave::Tools::Base
  tags :file_system_tool

  tool_name "glob_project_files"
  description "Searches for files matching the given glob pattern."

  arguments do
    required(:pattern).filled(:string).description('The glob pattern to match files against, e.g., \"**/*.ex\"')
  end

  def call(pattern:)
    Dir.glob(pattern, base: Tidewave::FileTracker.git_root)
  end
end
