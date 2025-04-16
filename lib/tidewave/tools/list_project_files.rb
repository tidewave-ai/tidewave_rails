# frozen_string_literal: true

class Tidewave::Tools::ListProjectFiles < Tidewave::Tools::Base
  tool_name "list_project_files"
  description "Returns a list of all files in the project that are not ignored by .gitignore."

  def call
    # Get git root directory
    git_root = `git rev-parse --show-toplevel`.strip

    # Change to git root directory to ensure git commands work properly
    Dir.chdir(git_root) do
      # Get tracked files
      tracked_files = `git ls-files`.split("\n")

      # Get untracked files that aren't ignored
      untracked_files = `git ls-files --others --exclude-standard`.split("\n")

      # Combine both sets of files
      return tracked_files + untracked_files
    end
  end
end
