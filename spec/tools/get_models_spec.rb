# frozen_string_literal: true

require "rails_helper"

describe Tidewave::Tools::GetModels do
  describe 'tags' do
    it 'does not include the file_system_tool tag' do
      expect(described_class.tags).not_to include(:file_system_tool)
    end
  end

  describe ".tool_name" do
    it "returns the correct tool name" do
      expect(described_class.tool_name).to eq("get_models")
    end
  end

  describe ".description" do
    it "returns the correct description" do
      expect(described_class.description).to eq(
        <<~DESCRIPTION
          Returns a list of all models in the application and their relationships.
        DESCRIPTION
      )
    end
  end

  describe ".input_schema_to_json" do
    it "returns the correct input schema" do
      expect(described_class.input_schema_to_json).to be_nil
    end
  end

  describe "#call" do
    let(:database_adapter) { instance_double("Tidewave::DatabaseAdapter") }
    let(:expected_response) do
      [
        {
          name: "User",
          relationships: [
            { name: :posts, type: :has_many },
            { name: :profile, type: :has_one }
          ]
        },
        {
          name: "Post",
          relationships: [
            { name: :user, type: :belongs_to }
          ]
        },
        {
          name: "Comment",
          relationships: []
        }
      ].to_json
    end

    before do
      allow(Tidewave::DatabaseAdapter).to receive(:current).and_return(database_adapter)
    end

    it "delegates to the database adapter" do
      expect(database_adapter).to receive(:get_models).and_return(expected_response)

      result = described_class.new.call

      expect(result).to eq(expected_response)
    end
  end
end
