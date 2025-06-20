# frozen_string_literal: true

require "fileutils"

describe Tidewave::Tools::ReadProjectFile do
  describe "tags" do
    it "includes the file_system_tool tag" do
      expect(described_class.tags).to include(:file_system_tool)
    end
  end

  describe ".tool_name" do
    it "returns the correct tool name" do
      expect(described_class.tool_name).to eq("read_project_file")
    end
  end

  describe ".description" do
    it "returns the correct description" do
      expect(described_class.description).to eq(
        <<~DESCRIPTION
          Returns the contents of the given file.
          Supports an optional line_offset and count. To read the full file, only the path needs to be passed.
        DESCRIPTION
      )
    end
  end

  describe "#call" do
    subject(:tool) { described_class.new }
    let(:path) { File.join("tmp", "read_project_file_test.txt") }
    let(:file_content) { "line1\nline2\nline3\nline4\nline5\n" }

    before do
      # Create tmp directory if it doesn't exist
      FileUtils.mkdir_p(File.dirname(path))
      # Write initial content to the test file
      File.write(path, file_content)
    end

    after do
      # Clean up test file
      FileUtils.rm_f(path)
    end

    it "returns the file content" do
      expect(tool.call(path: path)).to eq(file_content)
    end

    it "returns specific lines when line_offset and count are provided" do
      expect(tool.call(path: path, line_offset: 1, count: 2)).to eq("line2\nline3\n")
    end

    it "returns lines from offset to end when only line_offset is provided" do
      expect(tool.call(path: path, line_offset: 3)).to eq("line4\nline5\n")
    end

    it "stores the mtime in metadata" do
      mtime_before = File.mtime(path).to_i
      tool.call(path: path)
      expect(tool._meta[:mtime]).to eq(mtime_before)
    end

    context "with different file types" do
      let(:binary_path) { File.join("tmp", "binary_file.bin") }
      let(:binary_content) { [ 0xFF, 0x00, 0xAA, 0x55 ].pack("C*") }

      before do
        # Create binary file
        File.binwrite(binary_path, binary_content)
      end

      after do
        FileUtils.rm_f(binary_path)
      end

      it "correctly reads binary content" do
        result = tool.call(path: binary_path)
        # Force same encoding for comparison
        expect(result.force_encoding(Encoding::ASCII_8BIT)).to eq(binary_content)
      end
    end

    context "with file paths in subdirectories" do
      let(:nested_path) { File.join("tmp", "deeply", "nested", "directory", "file.txt") }
      let(:nested_content) { "content in nested file" }

      before do
        # Create directory structure
        FileUtils.mkdir_p(File.dirname(nested_path))
        # Create file with content
        File.write(nested_path, nested_content)
      end

      after do
        # Clean up
        FileUtils.rm_f(nested_path)
      end

      it "reads content from subdirectories" do
        expect(tool.call(path: nested_path)).to eq(nested_content)
      end
    end

    context "when the file does not exist" do
      let(:nonexistent_path) { File.join("tmp", "nonexistent_file.txt") }

      it "raises an ArgumentError" do
        expect { tool.call(path: nonexistent_path) }.to raise_error(
          ArgumentError, "File not found: #{nonexistent_path}"
        )
      end
    end

    context "when the file path is invalid" do
      it "raises an error for paths containing '..'" do
        invalid_path = "../outside_project.txt"

        expect { tool.call(path: invalid_path) }.to raise_error(
          ArgumentError, "File path must not contain '..'"
        )
      end

      it "raises an error for absolute paths" do
        absolute_path = Dir.home()

        expect { tool.call(path: absolute_path) }.to raise_error(
          ArgumentError, "File path must be within the project directory"
        )
      end
    end
  end
end
