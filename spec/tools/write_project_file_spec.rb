# frozen_string_literal: true

describe Tidewave::Tools::WriteProjectFile do
  let(:tool) { described_class.new }
  let(:path) { "test/file.rb" }
  let(:content) { "new file content" }

  before do
    allow(Tidewave::FileTracker).to receive(:file_exists?).and_return(true)
    allow(Tidewave::FileTracker).to receive(:file_not_read?).and_return(false)
    allow(Tidewave::FileTracker).to receive(:write_file)
  end

  it "checks if the file exists and hasn't been read" do
    expect(Tidewave::FileTracker).to receive(:file_exists?).with(path)
    expect(Tidewave::FileTracker).to receive(:file_not_read?).with(path)
    tool.call(path: path, content: content)
  end

  it "writes the content to the file" do
    expect(Tidewave::FileTracker).to receive(:write_file).with(path, content)
    tool.call(path: path, content: content)
  end

  it "raises an error if the file exists but has not been read" do
    allow(Tidewave::FileTracker).to receive(:file_exists?).with(path).and_return(true)
    allow(Tidewave::FileTracker).to receive(:file_not_read?).with(path).and_return(true)

    expect {
      tool.call(path: path, content: content)
    }.to raise_error(ArgumentError, "File must be read first")
  end

  it "doesn't raise an error if the file doesn't exist" do
    allow(Tidewave::FileTracker).to receive(:file_exists?).with(path).and_return(false)

    expect {
      tool.call(path: path, content: content)
    }.not_to raise_error
  end

  context "when writing different types of content" do
    it "handles empty content" do
      empty_content = ""
      expect(Tidewave::FileTracker).to receive(:write_file).with(path, empty_content)
      tool.call(path: path, content: empty_content)
    end

    it "handles multiline content" do
      multiline_content = "line 1\nline 2\nline 3"
      expect(Tidewave::FileTracker).to receive(:write_file).with(path, multiline_content)
      tool.call(path: path, content: multiline_content)
    end

    it "handles content with special characters" do
      special_content = "function() { return $x + $y; }"
      expect(Tidewave::FileTracker).to receive(:write_file).with(path, special_content)
      tool.call(path: path, content: special_content)
    end
  end

  context "with different file paths" do
    it "works with paths in subdirectories" do
      nested_path = "deeply/nested/directory/file.rb"

      allow(Tidewave::FileTracker).to receive(:file_exists?).with(nested_path).and_return(true)
      allow(Tidewave::FileTracker).to receive(:file_not_read?).with(nested_path).and_return(false)
      expect(Tidewave::FileTracker).to receive(:write_file).with(nested_path, content)

      tool.call(path: nested_path, content: content)
    end

    it "works with different file extensions" do
      different_extensions = [ "test.rb", "test.js", "test.html", "test.css", "test.md" ]

      different_extensions.each do |file_path|
        allow(Tidewave::FileTracker).to receive(:file_exists?).with(file_path).and_return(true)
        allow(Tidewave::FileTracker).to receive(:file_not_read?).with(file_path).and_return(false)
        expect(Tidewave::FileTracker).to receive(:write_file).with(file_path, content)

        tool.call(path: file_path, content: content)
      end
    end
  end
end
