# frozen_string_literal: true

require "tidewave/file_tracker"

class Tidewave::Tools::ReadProjectFile < Tidewave::Tools::Base
  tool_name "read_project_file"
  description <<~DESCRIPTION
    Returns the contents of the given file. Matches the `resources/read` MCP method.
  DESCRIPTION

  arguments do
    required(:path).filled(:string).description("The path to the file to read. It is relative to the project root.")
  end

  def call(path:)
    # Get git root directory
    git_root = `git rev-parse --show-toplevel`.strip

    # Ensure the path is within the project
    full_path = File.join(git_root, path)

    # Verify the file is within the project directory
    unless full_path.start_with?(git_root)
      raise ArgumentError, "File path must be within the project directory"
    end

    # Verify the file exists
    unless File.exist?(full_path)
      raise ArgumentError, "File not found: #{path}"
    end

    relative_path = full_path.split("#{git_root}/").last

    # Record the file as read, used to track when a file was last read before writing to it
    Tidewave::FileTracker.record_read(relative_path)

    # Read and return the file contents
    File.read(full_path)
  end
end
