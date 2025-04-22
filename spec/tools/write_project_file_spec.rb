# frozen_string_literal: true

describe Tidewave::Tools::WriteProjectFile do
  describe '.file_system_tool?' do
    it 'returns true' do
      expect(described_class.file_system_tool?).to be true
    end
  end

  describe '.tool_name' do
    it 'returns the tool name' do
      expect(described_class.tool_name).to eq('write_project_file')
    end
  end

  describe '.description' do
    it 'returns the tool description' do
      expect(described_class.description).to eq(
        <<~DESCRIPTION
          Writes a file to the file system. If the file already exists, it will be overwritten.

          Note that this tool will fail if the file wasn't previously read with the `read_project_file` tool.
        DESCRIPTION
      )
    end
  end

  describe '#call' do
    subject(:tool) { described_class.new }
    let(:path) { "test/file.rb" }
    let(:content) { "new file content" }

    before do
      allow(Tidewave::FileTracker).to receive(:validate_path_is_writable!).and_return(true)
      allow(Tidewave::FileTracker).to receive(:write_file)
    end

    it "validates the path is writable" do
      expect(Tidewave::FileTracker).to receive(:validate_path_is_writable!).with(path)
      tool.call(path: path, content: content)
    end

    it "writes the content to the file" do
      expect(Tidewave::FileTracker).to receive(:write_file).with(path, content)
      tool.call(path: path, content: content)
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

        expect(Tidewave::FileTracker).to receive(:validate_path_is_writable!).with(nested_path)
        expect(Tidewave::FileTracker).to receive(:write_file).with(nested_path, content)

        tool.call(path: nested_path, content: content)
      end

      it "works with different file extensions" do
        different_extensions = [ "test.rb", "test.js", "test.html", "test.css", "test.md" ]

        different_extensions.each do |file_path|
          expect(Tidewave::FileTracker).to receive(:validate_path_is_writable!).with(file_path)
          expect(Tidewave::FileTracker).to receive(:write_file).with(file_path, content)

          tool.call(path: file_path, content: content)
        end
      end
    end

    context "when validation fails" do
      it "lets the validation error propagate" do
        allow(Tidewave::FileTracker).to receive(:validate_path_is_writable!).and_raise(ArgumentError, "Validation failed")

        expect {
          tool.call(path: path, content: content)
        }.to raise_error(ArgumentError, "Validation failed")
      end
    end
  end
end
