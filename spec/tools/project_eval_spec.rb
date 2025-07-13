# frozen_string_literal: true

describe Tidewave::Tools::ProjectEval do
  describe 'tags' do
    it 'does not include the file_system_tool tag' do
      expect(described_class.tags).not_to include(:file_system_tool)
    end
  end

  describe ".tool_name" do
    it "returns the correct tool name" do
      expect(described_class.tool_name).to eq("project_eval")
    end
  end

  describe ".description" do
    it "returns the correct description" do
      expect(described_class.description).to match(
        /Evaluates Ruby code in the context of the project/
      )
    end
  end

  describe ".input_schema_to_json" do
    let(:expected_input_schema) do
      {
        properties: {
          code: {
            description: "The Ruby code to evaluate",
            type: "string"
          }
        },
        required: [ "code" ],
        type: "object"
      }
    end

    it "returns the correct input schema" do
      expect(described_class.input_schema_to_json).to eq(expected_input_schema)
    end
  end

  describe "#call" do
    let(:code) { nil }

    context "without code writing to stdout" do
      let(:code) { "1 + 1" }

      it "returns the correct result" do
        result = described_class.new.call(code: code)

        expect(result).to eq("2")
      end
    end

    context 'with code writing to stdout' do
      let(:code) { "puts 'Hello, world!'" }

      it "returns the correct result" do
        result = described_class.new.call(code: code)

        expect(result).to eq(<<~OUTPUT)
          STDOUT:

          Hello, world!


          STDERR:



          Result:


        OUTPUT
      end
    end

    context 'with code writing to stderr' do
      let(:code) { "warn 'Hello, world!'" }

      it "returns the correct result" do
        result = described_class.new.call(code: code)

        expect(result).to eq(<<~OUTPUT)
          STDOUT:



          STDERR:

          Hello, world!


          Result:


        OUTPUT
      end
    end

    context 'with code writing to stdout, stderr and returning a value' do
      let(:code) { "puts 'Hello, world!'; warn 'How you doin?'; 1 + 1" }

      it "returns the correct result" do
        result = described_class.new.call(code: code)

        expect(result).to eq(<<~OUTPUT)
          STDOUT:

          Hello, world!


          STDERR:

          How you doin?


          Result:

          2
        OUTPUT
      end
    end
  end
end
