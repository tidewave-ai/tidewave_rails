# frozen_string_literal: true

describe PackageSearch do
  describe ".tool_name" do
    it "returns the correct tool name" do
      expect(described_class.tool_name).to eq("package_search")
    end
  end

  describe ".description" do
    it "returns the correct description" do
      expect(described_class.description).to eq(
        <<~DESCRIPTION
          Searches for packages on RubyGems.

          Use this tool if you need to find new packages to add to the project. Before using this tool,
          get an overview of the existing dependencies by using the `project_eval` tool and executing `Mix.Project.deps_apps()`.

          The results are paginated, with 30 packages per page. Use the `page` parameter to fetch a specific page.
        DESCRIPTION
      )
    end
  end

  describe ".input_schema_to_json" do
    let(:expected_input_schema) do
      {
        properties: {
          search: {
            type: "string",
            description: "The search term"
          },
          page: {
            type: "number",
            description: "The page number to fetch. Must be greater than 0. Defaults to 1.",
            exclusiveMinimum: 0
          }
        },
        required: [ "search" ],
        type: "object"
      }
    end

    it "returns the correct input schema" do
      expect(described_class.input_schema_to_json).to eq(expected_input_schema)
    end
  end

  describe "#call" do
    let(:response_body) { File.read("spec/fixtures/package_search.json") }

    context "without page" do
      it "returns results for page 1" do
        faraday_double = instance_double('Faraday::Connection')
        response = instance_double('Faraday::Response')
        expect(faraday_double).to receive(:get).with("/api/v1/search.json?query=rails&page=1").and_return(response)
        expect(response).to receive(:body).and_return(response_body)

        expect(Faraday).to receive(:new).and_return(faraday_double)

        result = described_class.new.call_with_schema_validation!(search: "rails")

        expect(result).to eq(response_body)
      end
    end

    context "with page < 1" do
      it "raises an error" do
        expect(Faraday).not_to receive(:new)

        expect {
          described_class.new.call_with_schema_validation!(search: "rails", page: 0)
        }.to raise_error(FastMcp::Tool::InvalidArgumentsError, '{"page":["must be greater than 0"]}')
      end
    end

    context "with page" do
      it "returns results for the given page" do
        faraday_double = instance_double('Faraday::Connection')
        response = instance_double('Faraday::Response')
        expect(faraday_double).to receive(:get).with("/api/v1/search.json?query=rails&page=2").and_return(response)
        expect(response).to receive(:body).and_return(response_body)

        allow(Faraday).to receive(:new).and_return(faraday_double)

        result = described_class.new.call_with_schema_validation!(search: "rails", page: 2)

        expect(result).to eq(response_body)
      end
    end
  end
end
