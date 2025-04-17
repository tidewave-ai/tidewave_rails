# frozen_string_literal: true

describe Tidewave::Tools::EditProjectFile do
  let(:tool) { described_class.new }
  let(:path) { "test/file.rb" }
  let(:old_string) { "old content" }
  let(:new_string) { "new content" }
  let(:file_content) { "some before text\nold content\nsome after text" }
  let(:expected_content) { "some before text\nnew content\nsome after text" }

  before do
    allow(Tidewave::FileTracker).to receive(:validate_path_access!)
    allow(Tidewave::FileTracker).to receive(:file_read?).and_return(true)
    allow(Tidewave::FileTracker).to receive(:read_file).and_return(file_content)
    allow(Tidewave::FileTracker).to receive(:write_file)
  end

  it "validates the path access" do
    expect(Tidewave::FileTracker).to receive(:validate_path_access!).with(path)
    tool.call(path: path, old_string: old_string, new_string: new_string)
  end

  it "checks if the file has been read" do
    expect(Tidewave::FileTracker).to receive(:file_read?).with(path)
    tool.call(path: path, old_string: old_string, new_string: new_string)
  end

  it "reads the file content" do
    expect(Tidewave::FileTracker).to receive(:read_file).with(path)
    tool.call(path: path, old_string: old_string, new_string: new_string)
  end

  it "writes the modified content back to the file" do
    expect(Tidewave::FileTracker).to receive(:write_file).with(path, expected_content)
    tool.call(path: path, old_string: old_string, new_string: new_string)
  end

  it "raises an error if the file has not been read" do
    allow(Tidewave::FileTracker).to receive(:file_read?).with(path).and_return(false)

    expect {
      tool.call(path: path, old_string: old_string, new_string: new_string)
    }.to raise_error(ArgumentError, "File must be read first")
  end

  context "when modifying file content" do
    it "replaces the old string with the new string" do
      expect(Tidewave::FileTracker).to receive(:write_file) do |write_path, content|
        expect(write_path).to eq(path)
        expect(content).to eq(expected_content)
      end

      tool.call(path: path, old_string: old_string, new_string: new_string)
    end

    it "handles replacement with empty string" do
      expect(Tidewave::FileTracker).to receive(:write_file) do |write_path, content|
        expect(write_path).to eq(path)
        expect(content).to eq("some before text\n\nsome after text")
      end

      tool.call(path: path, old_string: old_string, new_string: "")
    end

    it "handles replacement with multiline string" do
      multiline_new = "new line 1\nnew line 2"
      expected = "some before text\nnew line 1\nnew line 2\nsome after text"

      expect(Tidewave::FileTracker).to receive(:write_file) do |write_path, content|
        expect(write_path).to eq(path)
        expect(content).to eq(expected)
      end

      tool.call(path: path, old_string: old_string, new_string: multiline_new)
    end
  end

  context "with code that includes special regex characters" do
    let(:file_content) { "function(arg1, arg2) { return arg1 + arg2; }" }
    let(:old_string) { "function(arg1, arg2) { return arg1 + arg2; }" }
    let(:new_string) { "function(arg1, arg2) { return arg1 * arg2; }" }

    it "correctly handles special regex characters" do
      expect(Tidewave::FileTracker).to receive(:write_file) do |write_path, content|
        expect(content).to eq(new_string)
      end

      tool.call(path: path, old_string: old_string, new_string: new_string)
    end
  end

  context "when multiple occurrences of the string exist" do
    let(:file_content) { "old content\nsome middle text\nold content" }

    it "replaces all occurrences of the string" do
      expect(Tidewave::FileTracker).to receive(:write_file) do |write_path, content|
        expect(content).to eq("new content\nsome middle text\nnew content")
      end

      tool.call(path: path, old_string: old_string, new_string: new_string)
    end
  end
end
