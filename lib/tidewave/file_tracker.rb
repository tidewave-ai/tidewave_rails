# frozen_string_literal: true

module Tidewave
  module FileTracker
    extend self

    def project_files
      # Change to git root directory to ensure git commands work properly
      Dir.chdir(git_root) do
        # Get tracked files
        tracked_files = `git ls-files`.split("\n")

        # Get untracked files that aren't ignored
        untracked_files = `git ls-files --others --exclude-standard`.split("\n")

        # Combine both sets of files
        tracked_files + untracked_files
      end
    end

    def read_file(path)
      validate_path_access!(path)


      # Retrieve the full path
      full_path = file_full_path(path)

      # Record the file as read
      record_read(path)

      # Read and return the file contents
      File.read(full_path)
    end

    def write_file(path, content)
      validate_path_access!(path, validate_existence: false)
      # Retrieve the full path
      full_path = file_full_path(path)

      dirname = File.dirname(full_path)

      # Create the directory if it doesn't exist
      FileUtils.mkdir_p(dirname)

      # Record the file as read
      record_read(path)

      # Write the file contents
      File.write(full_path, content)
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
      raise ArgumentError, "File not found: #{path}" unless File.exist?(full_path) && validate_existence

      path
    end

    # Record when a file was read
    def record_read(path)
      file_records[path] = Time.now
    end

    # Check if a file has not been read
    def file_not_read?(path)
      !file_read?(path)
    end

    # Check if a file has been read
    def file_read?(path)
      file_records.key?(path)
    end

    # Check if a file exists
    def file_exists?(path)
      File.exist?(file_full_path(path))
    end

    # Get the timestamp when a file was last read
    def last_read_at(path)
      file_records[path]
    end

    # Reset all tracked files (useful for testing)
    def reset
      @file_records = {}
    end

    # Hash mapping file paths to their read records
    def file_records
      @file_records ||= {}
    end
  end
end
