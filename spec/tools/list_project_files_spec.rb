# frozen_string_literal: true

describe Tidewave::Tools::ListProjectFiles do
  describe 'tags' do
    it 'includes the file_system_tool tag' do
      expect(described_class.tags).to include(:file_system_tool)
    end
  end

  describe ".tool_name" do
    it "returns the correct tool name" do
      expect(described_class.tool_name).to eq("list_project_files")
    end
  end

  describe ".description" do
    it "returns the correct description" do
      expect(described_class.description).to match(
        "Returns a list of files in the project"
      )
    end
  end

  describe "#call" do
    subject(:tool) { described_class.new }

    it 'calls project_files without pattern by default' do
      expect(Tidewave::FileTracker).to receive(:project_files).with(glob_pattern: nil).and_return([ "file1.rb", "file2.rb" ])
      expect(tool.call).to eq([ "file1.rb", "file2.rb" ])
    end

    it 'calls project_files with pattern when provided' do
      expect(Tidewave::FileTracker).to receive(:project_files).with(glob_pattern: "*.rb").and_return([ "file1.rb", "file2.rb" ])
      expect(tool.call(glob_pattern: "*.rb")).to eq([ "file1.rb", "file2.rb" ])
    end
  end
end
