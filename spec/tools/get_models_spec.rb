# frozen_string_literal: true

require "rails_helper"

# Define test models for this spec
class User < ActiveRecord::Base
  def self.table_exists?
    false
  end

  has_many :posts, class_name: 'Post', foreign_key: 'user_id'
  has_one :profile, class_name: 'Profile', foreign_key: 'user_id'
end

class Post < ActiveRecord::Base
  def self.table_exists?
    false
  end

  belongs_to :user, class_name: 'User', foreign_key: 'user_id'
end

class Comment < ActiveRecord::Base
  def self.table_exists?
    false
  end

  # No associations
end

class Profile < ActiveRecord::Base
  def self.table_exists?
    false
  end

  belongs_to :user, class_name: 'User', foreign_key: 'user_id'
end

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
    before do
      # Mock Rails.application.eager_load! to avoid loading all models
      allow(Rails.application).to receive(:eager_load!)

      # Mock ActiveRecord::Base.descendants to return only our test models
      allow(ActiveRecord::Base).to receive(:descendants).and_return([ User, Post, Comment ])
    end

    it "returns all models with all their relationships" do
      result = described_class.new.call

      # Find each model in the result
      user_result = result.find { |model| model[:name] == 'User' }
      post_result = result.find { |model| model[:name] == 'Post' }
      comment_result = result.find { |model| model[:name] == 'Comment' }

      # Verify User model
      expect(user_result[:name]).to eq('User')
      expect(user_result[:relationships]).to contain_exactly(
        { name: :posts, type: :has_many },
        { name: :profile, type: :has_one }
      )
      expect(user_result[:source_location]).to include('spec/tools/get_models_spec.rb')

      # Verify Post model
      expect(post_result[:name]).to eq('Post')
      expect(post_result[:relationships]).to contain_exactly(
        { name: :user, type: :belongs_to }
      )
      expect(post_result[:source_location]).to include('spec/tools/get_models_spec.rb')

      # Verify Comment model
      expect(comment_result[:name]).to eq('Comment')
      expect(comment_result[:relationships]).to eq([])
      expect(comment_result[:source_location]).to include('spec/tools/get_models_spec.rb')
    end

    it "handles models with missing source location array" do
      # Create a model class
      empty_source_model = Class.new(ActiveRecord::Base) do
        def self.table_exists?
          false
        end

        def self.name
          'EmptySourceModel'
        end
      end

      # Mock descendants to include our test model
      allow(ActiveRecord::Base).to receive(:descendants).and_return([ User, empty_source_model ])
      result = described_class.new.call

      # Find the model with empty source
      empty_result = result.find { |model| model[:name] == 'EmptySourceModel' }

      expect(empty_result[:name]).to eq('EmptySourceModel')
      expect(empty_result[:source_location]).to be_nil
    end
  end
end
