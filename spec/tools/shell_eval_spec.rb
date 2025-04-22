# frozen_string_literal: true

describe Tidewave::Tools::ShellEval do
  describe '.file_system_tool?' do
    it 'returns nil' do
      expect(described_class.file_system_tool?).to be nil
    end
  end

  describe '.tool_name' do
    it 'returns the name of the tool' do
      expect(described_class.tool_name).to eq('shell_eval')
    end
  end

  describe '.description' do
    it 'returns a description of the tool' do
      expect(described_class.description).to eq(<<~DESCRIPTION
        Executes a shell command in the project root directory.

        Avoid using this tool for file operations. Instead, rely on dedicated file system tools, if available.

        The operating system is of flavor #{RUBY_PLATFORM}.

        Only use this tool if other means are not available.
      DESCRIPTION
      )
    end
  end

  describe ".input_schema_to_json" do
    let(:expected_input_schema) do
      {
        properties: {
          command: {
            type: "string",
            description: "The shell command to execute. Avoid using this for file operations; use dedicated file system tools instead."
          }
        },
        required: [ "command" ],
        type: "object"
      }
    end

    it "returns the correct input schema" do
      expect(described_class.input_schema_to_json).to eq(expected_input_schema)
    end
  end

  describe '.call' do
    subject(:tool) { described_class.new }

    it 'executes the given command and returns the output' do
      output = tool.call(command: 'echo "Hello, World!"')
      expect(output).to eq('Hello, World!')
    end

    context 'when the command fails' do
      it 'raises an error' do
        expect { tool.call(command: 'echo "Hello, World!" && exit 1') }.to raise_error(
          Tidewave::Tools::ShellEval::CommandFailedError,
          "Command failed with status 1:\n\nHello, World!\n"
        )
      end
    end
  end
end
