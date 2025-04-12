# frozen_string_literal: true

describe GetSourceLocation do
  describe "#tool_name" do
    it "returns the correct tool name" do
      expect(GetSourceLocation.tool_name).to eq("get_source_location")
    end
  end

  describe "#ruby_version_compatible_label" do
    context "when Ruby version is compatible" do
      it "returns the correct label" do
        allow(GetSourceLocation).to receive(:ruby_version_compatible?).and_return(true)
        expect(GetSourceLocation.ruby_version_compatible_label).to eq("compatible")
      end
    end

    context "when Ruby version is not compatible" do
      it "returns the correct label" do
        allow(GetSourceLocation).to receive(:ruby_version_compatible?).and_return(false)
        expect(GetSourceLocation.ruby_version_compatible_label).to eq("incompatible")
      end
    end
  end

  describe "#ruby_version_compatible?" do
    context "when Ruby version is compatible" do
      it "returns true" do
        allow(GetSourceLocation).to receive(:ruby_version).and_return('3.4.0')
        expect(GetSourceLocation.ruby_version_compatible?).to eq(true)
      end
    end

    context "when Ruby version is not compatible" do
      it "returns false" do
        allow(GetSourceLocation).to receive(:ruby_version).and_return('3.3.0')
        expect(GetSourceLocation.ruby_version_compatible?).to eq(false)
      end
    end
  end

  describe "#description" do
    let(:description) do
      <<~DESCRIPTION
        Returns the source location for the given module (or function).

        This works for modules in the current project, as well as dependencies.

        This tool only works if you know the specific module (and optionally function) that is being targeted.
        If that is the case, prefer this tool over grepping the file system.

        ## Ruby version compatibility
        Due to a Ruby bug, this tool only works with Ruby >= 3.4.0.
        Your ruby version is compatible with this tool.
      DESCRIPTION
    end

    context "when Ruby version is compatible" do
      it "returns the correct description" do
        allow(GetSourceLocation).to receive(:ruby_version_compatible?).and_return(true)
        expect(GetSourceLocation.description).to eq(description)
      end
    end
  end

  describe "#input_schema_to_json" do
    let(:expected_input_schema) do
      {
        properties: {
          module_name: {
            type: "string",
            description: "The module to get source location for. When this is the single argument passed, the entire module source is returned."
          },
          function_name: {
            type: "string",
            description: "The function to get source location for. When used, a module must also be passed."
          }
        },
        required: [ "module_name" ],
        type: "object"
      }
    end

    it "returns the correct input schema" do
      expect(described_class.input_schema_to_json).to eq(expected_input_schema)
    end
  end
end
