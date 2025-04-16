# frozen_string_literal: true

module Tidewave
  module FileTracker
    extend self

    def project_files
      # Get git root directory
      git_root = `git rev-parse --show-toplevel`.strip

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

    # Record when a file was read
    def record_read(path)
      file_records[path] = Time.now
    end

    # Check if a file has been read
    def file_read?(path)
      file_records.key?(path)
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
