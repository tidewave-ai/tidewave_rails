# frozen_string_literal: true

describe Tidewave::Tools::RunRubocop do
  describe '.file_system_tool?' do
    it 'returns nil' do
      expect(described_class.file_system_tool?).to be nil
    end
  end

  describe '.tool_name' do
    it 'returns the name of the tool' do
      expect(described_class.tool_name).to eq('run_rubocop')
    end
  end

  describe '.description' do
    it 'returns a description of the tool' do
      expect(described_class.description).to match(
        /Runs RuboCop static code analyzer/
      )
      expect(described_class.description).to match(
        /community Ruby Style Guide/
      )
    end
  end

  describe ".input_schema_to_json" do
    let(:expected_input_schema) do
      {
        properties: {
          path: {
            type: "string",
            description: "The file or directory path to run RuboCop on. Defaults to the entire project."
          },
          options: {
            type: "string",
            description: "Additional RuboCop options (e.g., '--auto-correct', '--format=json')."
          }
        },
        type: "object"
      }
    end

    it "returns the correct input schema" do
      expect(described_class.input_schema_to_json).to eq(expected_input_schema)
    end
  end

  describe '.call' do
    subject(:tool) { described_class.new }

    before do
      # Reset the instance variable to ensure consistent test behavior
      subject.instance_variable_set(:@rubocop_installed, nil)
    end

    context 'when RuboCop is not installed' do
      before do
        allow(tool).to receive(:rubocop_installed?).and_return(false)
      end

      it 'raises a RubocopNotInstalledError' do
        expect { tool.call }.to raise_error(
          Tidewave::Tools::RunRubocop::RubocopNotInstalledError,
          /RuboCop gem is not installed in this project/
        )
      end
    end

    context 'when RuboCop is installed' do
      before do
        allow(tool).to receive(:rubocop_installed?).and_return(true)
        allow(Open3).to receive(:capture2e).and_return([ "Output from RuboCop", instance_double(Process::Status, exitstatus: 0) ])
      end

      it 'runs RuboCop and returns the output' do
        expect(Open3).to receive(:capture2e).with("bundle exec rubocop --no-color")
        expect(tool.call).to eq("Output from RuboCop")
      end

      it 'includes the path when provided' do
        expect(Open3).to receive(:capture2e).with("bundle exec rubocop --no-color app/models")
        tool.call(path: "app/models")
      end

      it 'includes options when provided' do
        expect(Open3).to receive(:capture2e).with("bundle exec rubocop --no-color --auto-correct")
        tool.call(options: "--auto-correct")
      end

      it 'includes both path and options when provided' do
        expect(Open3).to receive(:capture2e).with("bundle exec rubocop --no-color --auto-correct app/models")
        tool.call(path: "app/models", options: "--auto-correct")
      end

      context 'when RuboCop finds offenses (exit code 1)' do
        before do
          allow(Open3).to receive(:capture2e).and_return([ "RuboCop found offenses", instance_double(Process::Status, exitstatus: 1) ])
        end

        it 'returns the output without raising an error' do
          expect(tool.call).to eq("RuboCop found offenses")
        end
      end

      context 'when RuboCop command fails (exit code > 1)' do
        before do
          allow(Open3).to receive(:capture2e).and_return([ "RuboCop command failed", instance_double(Process::Status, exitstatus: 2) ])
        end

        it 'raises a CommandFailedError' do
          expect { tool.call }.to raise_error(
            Tidewave::Tools::RunRubocop::CommandFailedError,
            /RuboCop command failed with status 2/
          )
        end
      end
    end
  end
end
