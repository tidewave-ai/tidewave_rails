# frozen_string_literal: true

describe Tidewave::Tools::ReadProjectFile do
  describe ".tool_name" do
    it "returns the correct tool name" do
      expect(described_class.tool_name).to eq("read_project_file")
    end
  end

  describe ".description" do
    it "returns the correct description" do
      expect(described_class.description).to eq(
        <<~DESCRIPTION
          Returns the contents of the given file. Matches the `resources/read` MCP method.
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
      # Stub git root directory
      allow(subject).to receive(:`).with("git rev-parse --show-toplevel").and_return("#{git_root}\n")

      # Stub file existence check
      allow(File).to receive(:exist?).with(full_path).and_return(true)

      # Stub file content read
      allow(File).to receive(:read).with(full_path).and_return(file_content)

      # Stub FileTracker.record_read
      allow(Tidewave::FileTracker).to receive(:record_read).with(file_path)
    end

    it "returns the file content" do
      expect(subject.call(path: file_path)).to eq(file_content)
    end

    it "records the file read in FileTracker" do
      subject.call(path: file_path)
      expect(Tidewave::FileTracker).to have_received(:record_read).with(file_path)
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

    context "when the file path is outside the project directory" do
      before do
        malicious_path = "../../../etc/passwd"
        allow(File).to receive(:join).with(git_root, malicious_path).and_return("/etc/passwd")
      end

      it "raises an ArgumentError" do
        expect { subject.call(path: "../../../etc/passwd") }.to raise_error(
          ArgumentError, "File path must be within the project directory"
        )
      end
    end
  end
end
