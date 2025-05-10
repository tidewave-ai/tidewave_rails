# frozen_string_literal: true

require "tidewave/file_tracker"

class Tidewave::Tools::ReadProjectFile < Tidewave::Tools::Base
  file_system_tool

  tool_name "read_project_file"
  description <<~DESCRIPTION
    Returns the contents of the given file. Matches the `resources/read` MCP method.
  DESCRIPTION

  arguments do
    required(:path).filled(:string).description("The path to the file to read. It is relative to the project root.")
  end

  def call(path:)
    Tidewave::FileTracker.validate_path_access!(path)
    _meta[:mtime], contents = Tidewave::FileTracker.read_file(path)
    contents
  end
end
