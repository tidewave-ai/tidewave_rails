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
    it 'calls project_files' do
      expect(Tidewave::FileTracker).to receive(:project_files).and_return([ "file1.rb", "file2.rb" ])
      expect(described_class.new.call).to eq([ "file1.rb", "file2.rb" ])
    end
  end
end
