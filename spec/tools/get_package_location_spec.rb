# frozen_string_literal: true

describe Tidewave::Tools::GetPackageLocation do
  describe '.file_system_tool?' do
    it 'returns nil' do
      expect(described_class.file_system_tool?).to be nil
    end
  end

  describe ".tool_name" do
    it "returns the correct tool name" do
      expect(described_class.tool_name).to eq("get_package_location")
    end
  end

  describe ".description" do
    it "returns the correct description" do
      expect(described_class.description).to match(
        <<~DESCRIPTION
          Returns the location of dependency packages.
        DESCRIPTION
      )
    end
  end

  describe ".input_schema_to_json" do
    let(:expected_input_schema) do
      {
        properties: {
          package: {
            type: "string",
            description: "The name of the package to get the location of. If not provided, the location of all packages will be returned."
          }
        },
        type: "object"
      }
    end

    it "returns the correct input schema" do
      expect(described_class.input_schema_to_json).to eq(expected_input_schema)
    end
  end

  describe "#call" do
    context "when getting a specific package location" do
      it "returns the location of fast-mcp package" do
        result = subject.call(package: "fast-mcp")
        expect(result).to include("fast-mcp")
        expect(result).to match(%r{/.*gems/fast-mcp-[\d.]+})
        expect(File.directory?(result)).to be true
      end

      it "raises an error for non-existent package" do
        expect { subject.call(package: "non_existent_package_xyz") }.to raise_error(
          RuntimeError,
          "Package non_existent_package_xyz not found. Check your Gemfile for available packages."
        )
      end
    end

    context "when getting all package locations" do
      let(:result) { subject.call }

      it "returns a string with package listings" do
        expect(result).to be_a(String)
        expect(result).to include("fast-mcp:")
      end

      it "includes multiple packages" do
        lines = result.split("\n")
        expect(lines.length).to be > 1

        lines.each do |line|
          _name, path = line.split(": ", 2)
          full_path = File.expand_path(path, Dir.pwd)
          expect(File.directory?(full_path)).to be true
        end
      end
    end
  end
end
