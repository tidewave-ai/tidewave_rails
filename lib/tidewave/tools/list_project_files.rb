# frozen_string_literal: true

require "tidewave/file_tracker"

class Tidewave::Tools::ListProjectFiles < Tidewave::Tools::Base
  tags :file_system_tool

  tool_name "list_project_files"
  description "Returns a list of all files in the project that are not ignored by .gitignore."

  def call
    Tidewave::FileTracker.project_files
  end
end
