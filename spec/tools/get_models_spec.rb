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
          Returns a list of all models in the application.
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

    it "returns all models as text with their source locations" do
      result = described_class.new.call

      expect(result).to be_a(String)
      expect(result).to include("* User at")
      expect(result).to include("* Post at")
      expect(result).to include("* Comment at")
      expect(result).to include("spec/tools/get_models_spec.rb")
    end

    it "handles models with missing source location" do
      # Create a model class
      empty_source_model = Class.new(ActiveRecord::Base) do
        def self.table_exists?
          false
        end

        def self.name
          'EmptySourceModel'
        end
      end

      # Mock Object.const_source_location to return nil for this model
      allow(Object).to receive(:const_source_location).with('EmptySourceModel').and_return(nil)
      allow(Object).to receive(:const_source_location).with('User').and_call_original
      allow(Object).to receive(:const_source_location).with('Post').and_call_original

      # Mock descendants to include our test model
      allow(ActiveRecord::Base).to receive(:descendants).and_return([ User, empty_source_model ])
      result = described_class.new.call

      expect(result).to include("* User at")
      expect(result).to include("* EmptySourceModel")
    end

    it "formats output with each model on a separate line" do
      result = described_class.new.call
      lines = result.split("\n")

      expect(lines.length).to eq(3)
      lines.each do |line|
        expect(line).to start_with("* ")
      end
    end
  end
end
