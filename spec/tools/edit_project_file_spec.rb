# frozen_string_literal: true

require "fileutils"

describe Tidewave::Tools::EditProjectFile do
  describe "tags" do
    it "includes the file_system_tool tag" do
      expect(described_class.tags).to include(:file_system_tool)
    end
  end

  subject(:tool) { described_class.new }
  let(:path) { File.join("tmp", "edit_project_file_test.txt") }
  let(:old_string) { "old content" }
  let(:new_string) { "new content" }
  let(:file_content) { "some before text\n#{old_string}\nsome after text" }
  let(:expected_content) { "some before text\n#{new_string}\nsome after text" }

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

  it "modifies the file by replacing the old string with the new string" do
    result = tool.call(path: path, old_string: old_string, new_string: new_string)
    expect(result).to eq("OK")

    # Check that the file was modified correctly
    modified_content = File.read(path)
    expect(modified_content).to eq(expected_content)
  end

  it "handles replacement with empty string" do
    tool.call(path: path, old_string: old_string, new_string: "")

    modified_content = File.read(path)
    expect(modified_content).to eq("some before text\n\nsome after text")
  end

  it "handles replacement with multiline string" do
    multiline_new = "new line 1\nnew line 2"
    expected = "some before text\n#{multiline_new}\nsome after text"

    tool.call(path: path, old_string: old_string, new_string: multiline_new)

    modified_content = File.read(path)
    expect(modified_content).to eq(expected)
  end

  context "with code that includes special regex characters" do
    let(:file_content) { "function(arg1, arg2) { return arg1 + arg2; }" }
    let(:old_string) { "function(arg1, arg2) { return arg1 + arg2; }" }
    let(:new_string) { "function(arg1, arg2) { return arg1 * arg2; }" }

    it "correctly handles special regex characters" do
      tool.call(path: path, old_string: old_string, new_string: new_string)

      modified_content = File.read(path)
      expect(modified_content).to eq(new_string)
    end
  end

  context "when multiple occurrences of the old_string exist" do
    let(:file_content) { "#{old_string}\nsome middle text\n#{old_string}" }

    it "raises ArgumentError" do
      expect { tool.call(path: path, old_string: old_string, new_string: new_string) }.to raise_error(ArgumentError, "old_string is not unique")
    end
  end

  context "when there are no occurences of the old_string" do
    let(:file_content) { "some before text\ndifferent content\nsome after text" }

    it "raises ArgumentError" do
      expect { tool.call(path: path, old_string: old_string, new_string: new_string) }.to raise_error(ArgumentError, "old_string is not found")
    end
  end

  context "when the file doesn't exist" do
    let(:nonexistent_path) { "tmp/nonexistent_file.txt" }

    it "raises ArgumentError" do
      expect { tool.call(path: nonexistent_path, old_string: old_string, new_string: new_string) }.to raise_error(ArgumentError, /File not found/)
    end
  end

  context "with file modification time validation" do
    it "raises an error if the file has been modified since last read" do
      # Read the file to get its mtime
      _, _ = Tidewave::FileTracker.read_file(path)

      # Modify the file to change its mtime
      File.write(path, file_content)
      # Set the mtime explicitly to be newer than when we read it
      future_time = Time.now + 10
      File.utime(future_time, future_time, path)

      # Try to edit with an old atime
      current_time = Time.now.to_i
      expect {
        tool.call(path: path, old_string: old_string, new_string: new_string, atime: current_time)
      }.to raise_error(ArgumentError, /File has been modified since last read/)
    end

    it "succeeds when providing a current atime" do
      # Read the file to get its mtime
      mtime, _ = Tidewave::FileTracker.read_file(path)

      # Edit with the current atime
      result = tool.call(path: path, old_string: old_string, new_string: new_string, atime: mtime)
      expect(result).to eq("OK")
    end
  end
end
