# frozen_string_literal: true

describe Tidewave::Tools::ListProjectFiles do
  describe ".tool_name" do
    it "returns the correct tool name" do
      expect(described_class.tool_name).to eq("list_project_files")
    end
  end

  describe ".description" do
    it "returns the correct description" do
      expect(described_class.description).to eq(
        "Returns a list of all files in the project that are not ignored by .gitignore."
      )
    end
  end

  describe "#call" do
    before do
      # Stub the git repository check
      allow(subject).to receive(:system).with("git rev-parse --is-inside-work-tree > /dev/null 2>&1").and_return(true)

      # Stub git root directory
      allow(subject).to receive(:`).with("git rev-parse --show-toplevel").and_return("/path/to/repo\n")

      # Stub Dir.chdir to execute the block directly without changing directory
      allow(Dir).to receive(:chdir).and_yield

      # Stub git ls-files for tracked files
      tracked_files = "file1.rb\nfile2.rb\n"
      allow(subject).to receive(:`).with("git ls-files").and_return(tracked_files)

      # Stub git ls-files for untracked files
      untracked_files = "file3.rb\n"
      allow(subject).to receive(:`).with("git ls-files --others --exclude-standard").and_return(untracked_files)
    end

    it "returns both tracked and untracked files" do
      expected_files = [ "file1.rb", "file2.rb", "file3.rb" ]
      expect(subject.call).to match_array(expected_files)
    end
  end
end
