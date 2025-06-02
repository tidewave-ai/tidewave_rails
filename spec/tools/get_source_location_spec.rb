# frozen_string_literal: true

describe Tidewave::Tools::GetSourceLocation do
  describe 'tags' do
    it 'does not include the file_system_tool tag' do
      expect(described_class.tags).not_to include(:file_system_tool)
    end
  end

  describe ".tool_name" do
    it "returns the correct tool name" do
      expect(described_class.tool_name).to eq("get_source_location")
    end
  end

  describe ".description" do
    let(:description) do
      <<~DESCRIPTION
        Returns the source location for the given reference.
      DESCRIPTION
    end

    it "returns the correct description" do
      expect(described_class.description).to match(description)
    end
  end

  describe "#input_schema_to_json" do
    let(:expected_input_schema) do
      {
        properties: {
          reference: {
            type: "string",
            description: "The constant/method to lookup, such String, String#gsub or File.executable?"
          }
        },
        required: [ "reference" ],
        type: "object"
      }
    end

    it "returns the correct input schema" do
      expect(described_class.input_schema_to_json).to eq(expected_input_schema)
    end
  end

  describe "#call" do
    subject { described_class.new.call(reference: reference) }

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

    let(:line_number) { __LINE__ + 1 }
    Object.const_set(:TidewaveTestModule, test_module)

    let(:baz_line_number) { __LINE__ + 1 }
    TidewaveTestModule.const_set(:BAZ, 123)

    context "when the module is found" do
      let(:reference) { 'TidewaveTestModule' }

      it "returns the correct result" do
        expect(subject).to eq({
          file_path: __FILE__,
          line_number: line_number
        }.to_json)
      end
    end

    context "when the module is not found" do
      let(:reference) { "NonExistentModule" }

      it "raises" do
        expect { subject }.to raise_error(NameError, "could not find source location for NonExistentModule")
      end
    end

    context "when the module is invalid" do
      let(:reference) { "1+2" }

      it "raises" do
        expect { subject }.to raise_error(NameError, "wrong constant name 1+2")
      end
    end

    context "when the constant is found" do
      let(:reference) { 'TidewaveTestModule::BAZ' }

      it "returns the correct result" do
        expect(subject).to eq({
          file_path: __FILE__,
          line_number: baz_line_number
        }.to_json)
      end
    end

    context "when the constant path is not a constant (with valid method)" do
      let(:reference) { "1+2#gsub" }

      it "raises" do
        expect { subject }.to raise_error(NameError, "wrong constant name 1+2")
      end
    end

    context "when the constant path is not a module (with valid method)" do
      let(:reference) { "TidewaveTestModule::BAZ#gsub" }

      it "raises" do
        expect { subject }.to raise_error(RuntimeError, "reference TidewaveTestModule::BAZ does not point a class/module")
      end
    end

    context "when the class method exists" do
      let(:reference) { 'TidewaveTestModule.foo' }

      it "returns the correct result" do
        expect(subject).to eq({
          file_path: __FILE__,
          line_number: foo_line_number
        }.to_json)
      end
    end

    context "when the class method does not exist" do
      let(:reference) { 'TidewaveTestModule.unknown' }

      it "raises" do
        expect { subject }.to raise_error(NameError, "undefined method `unknown' for class `#<Class:TidewaveTestModule>'")
      end
    end

    context "when the instance method exists" do
      let(:reference) { 'TidewaveTestModule#bar' }

      it "returns the correct result" do
        expect(subject).to eq({
          file_path: __FILE__,
          line_number: bar_line_number
        }.to_json)
      end
    end

    context "when the instance method does not exist" do
      let(:reference) { 'TidewaveTestModule#unknown' }

      it "raises" do
        expect { subject }.to raise_error(NameError, "undefined method `unknown' for class `TidewaveTestModule'")
      end
    end
  end
end
