# frozen_string_literal: true

require "fileutils"

describe Tidewave::Tools::WriteProjectFile do
  describe "tags" do
    it "includes the file_system_tool tag" do
      expect(described_class.tags).to include(:file_system_tool)
    end
  end

  describe ".tool_name" do
    it "returns the tool name" do
      expect(described_class.tool_name).to eq("write_project_file")
    end
  end

  describe ".description" do
    it "returns the tool description" do
      expect(described_class.description).to eq(
        <<~DESCRIPTION
          Writes a file to the file system. If the file already exists, it will be overwritten.

          Note that this tool will fail if the file wasn't previously read with the `read_project_file` tool.
        DESCRIPTION
      )
    end
  end

  describe "#call" do
    subject(:tool) { described_class.new }
    let(:path) { File.join("tmp", "write_project_file_test.txt") }
    let(:content) { "new file content" }

    before do
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "initial content")
    end

    after do
      FileUtils.rm_f(path)
    end

    it "writes the content to the file" do
      result = tool.call(path: path, content: content)
      expect(result).to eq("OK")

      # Check that the file was modified correctly
      file_content = File.read(path)
      expect(file_content).to eq(content)
    end

    context "when writing different types of content" do
      it "handles empty content" do
        empty_content = ""
        tool.call(path: path, content: empty_content)

        file_content = File.read(path)
        expect(file_content).to eq(empty_content)
      end

      it "handles multiline content" do
        multiline_content = "line 1\nline 2\nline 3"
        tool.call(path: path, content: multiline_content)

        file_content = File.read(path)
        expect(file_content).to eq(multiline_content)
      end

      it "handles content with special characters" do
        special_content = "function() { return $x + $y; }"
        tool.call(path: path, content: special_content)

        file_content = File.read(path)
        expect(file_content).to eq(special_content)
      end
    end

    context "with different file paths" do
      let(:nested_path) { File.join("tmp", "deeply", "nested", "directory", "file.txt") }

      before do
        FileUtils.mkdir_p(File.dirname(nested_path))
        File.write(nested_path, "initial content")
      end

      after do
        FileUtils.rm_f(nested_path)
      end

      it "works with paths in subdirectories" do
        result = tool.call(path: nested_path, content: content)
        expect(result).to eq("OK")

        file_content = File.read(nested_path)
        expect(file_content).to eq(content)
      end
    end

    context "with file modification time validation" do
      it "raises an error if the file has been modified since last read" do
        # Read the file to get its mtime
        mtime, _ = Tidewave::FileTracker.read_file(path)

        # Modify the file to change its mtime
        File.write(path, "modified content")

        # Set the mtime explicitly to be newer than when we read it
        future_time = Time.now + 10
        File.utime(future_time, future_time, path)

        # Try to write with an old atime
        expect {
          tool.call(path: path, content: content, atime: mtime)
        }.to raise_error(ArgumentError, /File has been modified since last read/)
      end

      it "succeeds when providing a current atime" do
        # Read the file to get its mtime
        mtime, _ = Tidewave::FileTracker.read_file(path)

        result = tool.call(path: path, content: content, atime: mtime)
        expect(result).to eq("OK")

        file_content = File.read(path)
        expect(file_content).to eq(content)
      end
    end

    context "when the path is invalid" do
      it "raises an error for paths containing '..'" do
        invalid_path = "../outside_project.txt"

        expect {
          tool.call(path: invalid_path, content: content)
        }.to raise_error(ArgumentError, /File path must not contain/)
      end
    end
  end
end
