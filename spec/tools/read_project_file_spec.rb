# frozen_string_literal: true

describe Tidewave::Tools::ReadProjectFile do
  describe '.file_system_tool?' do
    it 'returns true' do
      expect(described_class.file_system_tool?).to be true
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

  describe ".input_schema_to_json" do
    let(:expected_input_schema) do
      {
        properties: {
          path: {
            type: "string",
            description: "The path to the file to read. It is relative to the project root."
          },
          line_offset: {
            type: "number",
            description: "Optional: the starting line offset from which to read. Defaults to 0."
          },
          count: {
            type: "number",
            description: "Optional: the number of lines to read. Defaults to all."
          }
        },
        required: [ "path" ],
        type: "object"
      }
    end

    it "returns the correct input schema" do
      expect(described_class.input_schema_to_json).to eq(expected_input_schema)
    end
  end

  describe "#call" do
    let(:git_root) { "/path/to/repo" }
    let(:file_path) { "app/models/user.rb" }
    let(:full_path) { File.join(git_root, file_path) }
    let(:file_content) { "class User < ApplicationRecord\nend\n" }

    before do
      allow(Tidewave::FileTracker).to receive(:git_root).and_return(git_root)
      allow(File).to receive(:exist?).with(full_path).and_return(true)
      allow(File).to receive(:read).with(full_path).and_return(file_content)
      allow(File).to receive(:mtime).with(full_path).and_return(Time.new(1971))
    end

    it "returns the file content" do
      expect(subject.call(path: file_path)).to eq(file_content)
    end

    it "returns specific lines when line_offset and count are provided" do
      multiline_content = "line1\nline2\nline3\nline4\nline5\n"
      allow(File).to receive(:read).with(full_path).and_return(multiline_content)

      expect(subject.call(path: file_path, line_offset: 1, count: 2)).to eq("line2\nline3\n")
    end

    it "returns lines from offset to end when only line_offset is provided" do
      multiline_content = "line1\nline2\nline3\nline4\nline5\n"
      allow(File).to receive(:read).with(full_path).and_return(multiline_content)

      expect(subject.call(path: file_path, line_offset: 3)).to eq("line4\nline5\n")
    end

    it "returns the mtime in metadata" do
      subject.call(path: file_path)
      expect(subject._meta[:mtime]).to eq(Time.new(1971).to_i)
    end

    context "when the file does not exist" do
      before do
        allow(File).to receive(:exist?).with(full_path).and_return(false)
      end

      it "raises an ArgumentError" do
        expect { subject.call(path: file_path) }.to raise_error(
          ArgumentError, "File not found: #{file_path}"
        )
      end
    end

    context "when the file path starts with '..'" do
      let(:higher_path) { "../../../etc/passwd" }

      before do
        allow(File).to receive(:join).with(git_root, higher_path).and_return("/etc/passwd")
      end

      it "raises an ArgumentError" do
        expect { subject.call(path: higher_path) }.to raise_error(
          ArgumentError, "File path must not contain '..'"
        )
      end
    end

    context "when the file path starts with '..'" do
      let(:malicious_path) { "/Users/sth/etc/passwd" }

      before do
        allow(File).to receive(:join).with(git_root, malicious_path).and_return("/etc/passwd")
      end

      it "raises an ArgumentError" do
        expect { subject.call(path: malicious_path) }.to raise_error(
          ArgumentError, "File path must be within the project directory"
        )
      end
    end
  end
end
