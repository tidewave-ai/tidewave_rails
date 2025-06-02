# frozen_string_literal: true

describe Tidewave::Tools::PackageSearch do
  describe 'tags' do
    it 'does not include the file_system_tool tag' do
      expect(described_class.tags).not_to include(:file_system_tool)
    end
  end

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
          get an overview of the existing dependencies by using the `project_eval` tool and executing
          `Gem::Specification.map { |gem| [gem.name, gem.version] }`.

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
    let(:http_response) { instance_double('Net::HTTPSuccess') }

    let(:parsed_response) do
      JSON.parse(response_body).map do |package|
        {
          name: package["name"],
          version: package["version"],
          downloads: package["downloads"],
          documentation_uri: package["documentation_uri"]
        }
      end
    end

    before do
      allow(http_response).to receive(:body).and_return(response_body)
      allow(http_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    end

    context "without page" do
      it "returns results for page 1" do
        uri = URI("https://rubygems.org/api/v1/search.json")
        uri.query = URI.encode_www_form(query: "rails", page: 1)

        expect(Net::HTTP).to receive(:get_response).with(uri).and_return(http_response)

        result = described_class.new.call(search: "rails")
        expect(result).to eq(parsed_response)
      end
    end

    context "with page" do
      it "returns results for the given page" do
        uri = URI("https://rubygems.org/api/v1/search.json")
        uri.query = URI.encode_www_form(query: "rails", page: 2)

        expect(Net::HTTP).to receive(:get_response).with(uri).and_return(http_response)

        result = described_class.new.call(search: "rails", page: 2)
        expect(result).to eq(parsed_response)
      end
    end
  end
end
