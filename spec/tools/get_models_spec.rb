# frozen_string_literal: true

require "rails_helper"

describe Tidewave::Tools::GetModels do
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
    let(:expected_input_schema) do
      {
        properties: {
          association_type: {
            type: "string",
            description: "The type of association to include in the response. Can be 'has_many', 'has_one' or 'belongs_to'. If omitted, all association types will be included.",
            enum: %w[has_many has_one belongs_to]
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
      allow(user_model).to receive(:reflect_on_all_associations).with(nil).and_return([ has_many_association, has_one_association ])
      allow(user_model).to receive(:reflect_on_all_associations).with(:has_many).and_return([ has_many_association ])
      allow(user_model).to receive(:reflect_on_all_associations).with(:has_one).and_return([ has_one_association ])
      allow(user_model).to receive(:reflect_on_all_associations).with(:belongs_to).and_return([])

      allow(post_model).to receive(:reflect_on_all_associations).with(nil).and_return([ belongs_to_association ])
      allow(post_model).to receive(:reflect_on_all_associations).with(:has_many).and_return([])
      allow(post_model).to receive(:reflect_on_all_associations).with(:has_one).and_return([])
      allow(post_model).to receive(:reflect_on_all_associations).with(:belongs_to).and_return([ belongs_to_association ])

      allow(comment_model).to receive(:reflect_on_all_associations).with(nil).and_return([])
      allow(comment_model).to receive(:reflect_on_all_associations).with(:has_many).and_return([])
      allow(comment_model).to receive(:reflect_on_all_associations).with(:has_one).and_return([])
      allow(comment_model).to receive(:reflect_on_all_associations).with(:belongs_to).and_return([])
    end

    context "when no association_type is provided" do
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

    context "when association_type is 'has_many'" do
      it "returns all models with only has_many relationships" do
        expected_response = [
          {
            name: "User",
            relationships: [
              { name: :posts, type: :has_many }
            ]
          },
          {
            name: "Post",
            relationships: []
          },
          {
            name: "Comment",
            relationships: []
          }
        ].to_json

        expect(described_class.new.call(association_type: "has_many")).to eq(expected_response)
      end
    end

    context "when association_type is 'belongs_to'" do
      it "returns all models with only belongs_to relationships" do
        expected_response = [
          {
            name: "User",
            relationships: []
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

        expect(described_class.new.call(association_type: "belongs_to")).to eq(expected_response)
      end
    end

    context "when association_type is 'has_one'" do
      it "returns all models with only has_one relationships" do
        expected_response = [
          {
            name: "User",
            relationships: [
              { name: :profile, type: :has_one }
            ]
          },
          {
            name: "Post",
            relationships: []
          },
          {
            name: "Comment",
            relationships: []
          }
        ].to_json

        expect(described_class.new.call(association_type: "has_one")).to eq(expected_response)
      end
    end
  end
end
