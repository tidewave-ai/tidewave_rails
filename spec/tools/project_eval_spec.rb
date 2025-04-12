describe ProjectEval do
  describe "#tool_name" do
    it "returns the correct tool name" do
      expect(ProjectEval.tool_name).to eq("project_eval")
    end
  end

  describe "#description" do
    it "returns the correct description" do
      expect(ProjectEval.description).to eq(
        <<~DESCRIPTION
          Evaluates Ruby code in the context of the project.

          The current Ruby version is: #{RUBY_VERSION}

          The code is executed in the context of the user's project, therefore use this tool any
          time you need to evaluate code, for example to test the behavior of a function or to debug
          something. The tool also returns anything written to standard output.
        DESCRIPTION
      )
    end
  end

  describe "#input_schema_to_json" do
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
      expect(ProjectEval.input_schema_to_json).to eq(expected_input_schema)
    end
  end

  describe "#call" do
    let(:code) { nil }

    context "without code writing to stdout" do
      let(:code) { "1 + 1" }

      it "returns the correct result" do
        result = ProjectEval.new.call_with_schema_validation!(code: code)

        expect(result).to eq(2)
      end
    end

    context 'with code writing to stdout' do
      let(:code) { "puts 'Hello, world!'" }

      it "returns the correct result" do
        result = ProjectEval.new.call_with_schema_validation!(code: code)

        expect(result).to eq({
          stdout: "Hello, world!\n",
          result: nil
        })
      end
    end

    context 'with code writing to stdout and returning a value' do
      let(:code) { "puts 'Hello, world!'; 1 + 1" }

      it "returns the correct result" do
        result = ProjectEval.new.call_with_schema_validation!(code: code)

        expect(result).to eq({
          stdout: "Hello, world!\n",
          result: 2
        })
      end
    end
  end
end
