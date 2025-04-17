# frozen_string_literal: true

require "tidewave/file_tracker"

# TODO: This tool is not yet implemented, it does not track the latest file read.
# Also, it does not raise an error if the file contains the substring multiple times.
class Tidewave::Tools::EditProjectFile < Tidewave::Tools::Base
  tool_name "edit_project_file"
  description <<~DESCRIPTION
    A tool for editing parts of a file. It can find and replace text inside a file.
    For moving or deleting files, use the shell_eval tool with 'mv' or 'rm' instead.

    For large edits, use the write_project_file tool instead and overwrite the entire file.

    Before editing, ensure to read the source file using the read_project_file tool.

    To use this tool, provide the path to the file, the old_string to search for, and the new_string to replace it with.
    If the old_string is found multiple times, an error will be returned. To ensure uniqueness, include a couple of lines
    before and after the edit. All whitespace must be preserved as in the original file.

    This tool can only do a single edit at a time. If you need to make multiple edits, you can create a message with
    multiple tool calls to this tool, ensuring that each one contains enough context to uniquely identify the edit.
  DESCRIPTION

  arguments do
    required(:path).filled(:string).description("The path to the file to edit. It is relative to the project root.")
    required(:old_string).filled(:string).description("The string to search for")
    required(:new_string).filled(:string).description("The string to replace the old_string with")
  end

  def call(path:, old_string:, new_string:)
    Tidewave::FileTracker.validate_path_access!(path)

    raise ArgumentError, "File must be read first" unless Tidewave::FileTracker.file_read?(path)

    old_content = Tidewave::FileTracker.read_file(path)

    new_content = old_content.gsub(old_string, new_string)

    Tidewave::FileTracker.write_file(path, new_content)
  end
end
