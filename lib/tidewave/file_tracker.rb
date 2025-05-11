# frozen_string_literal: true

module Tidewave
  module FileTracker
    extend self

    def project_files
      `git --git-dir #{git_root}/.git ls-files --cached --others --exclude-standard`.split("\n")
    end

    def read_file(path)
      full_path = file_full_path(path)
      # Explicitly read the mtime first to avoid race conditions
      mtime = File.mtime(full_path).to_i
      [ mtime, File.read(full_path) ]
    end

    def write_file(path, content)
      full_path = file_full_path(path)

      # Create the directory if it doesn't exist
      dirname = File.dirname(full_path)
      FileUtils.mkdir_p(dirname)

      # Write and return the file contents
      File.write(full_path, content)
      content
    end

    def file_full_path(path)
      File.join(git_root, path)
    end

    def git_root
      @git_root ||= `git rev-parse --show-toplevel`.strip
    end

    def validate_path_access!(path, validate_existence: true)
      raise ArgumentError, "File path must not start with '..'" if path.start_with?("..")

      # Ensure the path is within the project
      full_path = file_full_path(path)

      # Verify the file is within the project directory
      raise ArgumentError, "File path must be within the project directory" unless full_path.start_with?(git_root)

      # Verify the file exists
      raise ArgumentError, "File not found: #{path}" if validate_existence && !File.exist?(full_path)

      true
    end

    def validate_path_is_editable!(path, atime)
      validate_path_access!(path)
      validate_path_has_been_read_since_last_write!(path, atime)

      true
    end

    def validate_path_is_writable!(path, atime)
      validate_path_access!(path, validate_existence: false)
      validate_path_has_been_read_since_last_write!(path, atime)

      true
    end

    def validate_path_has_been_read_since_last_write!(path, atime)
      if atime && File.mtime(file_full_path(path)).to_i > atime
        raise ArgumentError, "File has been modified since last read, please read the file again"
      end

      true
    end
  end
end
