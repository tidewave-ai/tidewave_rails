# frozen_string_literal: true

describe GetSourceLocation do
  describe ".tool_name" do
    it "returns the correct tool name" do
      expect(GetSourceLocation.tool_name).to eq("get_source_location")
    end
  end

  describe ".ruby_version_compatible_label" do
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

  describe ".ruby_version_compatible?" do
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

  describe ".description" do
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

  describe "#call" do
    context 'with module_name as argument' do
      subject { GetSourceLocation.new.call_with_schema_validation!(module_name: module_name) }

      let(:module_name) { 'TidewaveTestModule' }
      let(:foo_line_number) { __LINE__ + 3 }
      let(:bar_line_number) { __LINE__ + 6 }
      test_module = Class.new do
        def self.foo
          'foo'
        end

        def bar
          'bar'
        end
      end

      # This is a bit of a hack to get the line number of the module definition.
      # It's not the best way to do it, but it's the only way I can think of to get the line number of the module definition.
      # If you know a better way, please let me know.
      let(:line_number) { __LINE__ + 1 }
      Object.const_set(:TidewaveTestModule, test_module)

      context "when the module is found" do
        it "returns the correct result" do
          expect(subject).to eq({
            file_path: __FILE__,
            line_number: line_number
          }.to_json)
        end
      end

      context "when the module is not found" do
        let(:module_name) { "NonExistentModule" }

        it "returns nil" do
          expect { subject }.to raise_error(NameError, "Module NonExistentModule not found")
        end
      end

      context 'with function_name as argument' do
        subject { GetSourceLocation.new.call_with_schema_validation!(module_name: module_name, function_name: function_name) }

        let(:class_method_name) { 'foo' }
        let(:instance_method_name) { 'bar' }
        let(:non_existent_method_name) { 'baz' }

        context "when the class method exists" do
          let(:function_name) { class_method_name }
          it "returns the correct result" do
            expect(subject).to eq({
              file_path: __FILE__,
              line_number: foo_line_number
            }.to_json)
          end
        end

        context "when the instance method exists" do
          let(:function_name) { instance_method_name }
          it "returns the correct result" do
            expect(subject).to eq({
              file_path: __FILE__,
              line_number: bar_line_number
            }.to_json)
          end
        end

        context "when the method does not exist" do
          let(:function_name) { non_existent_method_name }

          it "returns nil" do
            expect { subject }.to raise_error(NameError, "Method baz not found in module TidewaveTestModule")
          end
        end
      end
    end
  end
end
