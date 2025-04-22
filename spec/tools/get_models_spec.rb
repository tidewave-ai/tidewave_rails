# frozen_string_literal: true

require "rails_helper"

describe Tidewave::Tools::GetModels do
  describe '.file_system_tool?' do
    it 'returns nil' do
      expect(described_class.file_system_tool?).to be nil
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
    let(:user_model) { double("User", name: "User") }
    let(:post_model) { double("Post", name: "Post") }
    let(:comment_model) { double("Comment", name: "Comment") }

    let(:models) { [ user_model, post_model, comment_model ] }

    let(:has_many_association) { double("has_many_association", name: :posts, macro: :has_many) }
    let(:belongs_to_association) { double("belongs_to_association", name: :user, macro: :belongs_to) }
    let(:has_one_association) { double("has_one_association", name: :profile, macro: :has_one) }

    before do
      # Mock Rails.application.eager_load!
      allow(Rails.application).to receive(:eager_load!)

      # Mock ActiveRecord::Base.descendants
      allow(ActiveRecord::Base).to receive(:descendants).and_return(models)

      # Set up the relationships for each model
      allow(user_model).to receive(:reflect_on_all_associations).and_return([ has_many_association, has_one_association ])

      allow(post_model).to receive(:reflect_on_all_associations).and_return([ belongs_to_association ])

      allow(comment_model).to receive(:reflect_on_all_associations).and_return([])
    end

    it "returns all models with all their relationships" do
      expected_response = [
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

      expect(described_class.new.call).to eq(expected_response)
    end
  end
end
