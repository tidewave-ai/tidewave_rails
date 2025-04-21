# frozen_string_literal: true

describe Tidewave::Tools::GlobProjectFiles do
  describe '.tool_name' do
    it 'returns the name of the tool' do
      expect(described_class.tool_name).to eq('glob_project_files')
    end
  end

  describe '.description' do
    it 'returns the description of the tool' do
      expect(described_class.description).to eq('Searches for files matching the given glob pattern.')
    end
  end

  describe "#input_schema_to_json" do
    let(:expected_input_schema) do
      {
        properties: {
          pattern: {
            type: "string",
            description: 'The glob pattern to match files against, e.g., \"**/*.ex\"'
          }
        },
        required: [ "pattern" ],
        type: "object"
      }
    end

    it "returns the correct input schema" do
      expect(described_class.input_schema_to_json).to eq(expected_input_schema)
    end
  end

  describe '#call' do
    subject(:tool) { described_class.new }

    it 'returns a JSON array of files matching the pattern' do
      expect(Tidewave::FileTracker).to receive(:git_root).and_return('/path/to/git/root')
      expect(Dir).to receive(:glob).with('**/*.rb', base: '/path/to/git/root').and_return([ 'tidewave.rb', 'glob.rb' ])

      expect(tool.call(pattern: '**/*.rb')).to eq([ 'tidewave.rb', 'glob.rb' ])
    end
  end
end
