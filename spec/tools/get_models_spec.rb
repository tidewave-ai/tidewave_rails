# frozen_string_literal: true

require "rails_helper"
require "tidewave/database_adapters/sequel"

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

      expect(lines.length).to be >= 3
      lines.each do |line|
        expect(line).to start_with("* ")
      end
    end

    context "with Sequel ORM" do
      before do
        # Mock Rails configuration for Sequel
        allow(Rails.application.config.tidewave).to receive(:preferred_orm).and_return(:sequel)

        # Create mock Sequel models - one named, one anonymous
        account_model = double("Account", name: "Account")
        anonymous_model = double("AnonymousModel", name: "Sequel::_Model(:accounts)")

        sequel_model_class = double("SequelModelClass")
        allow(sequel_model_class).to receive(:descendants).and_return([ account_model, anonymous_model ])

        # Mock the database adapter
        sequel_adapter = instance_double(Tidewave::DatabaseAdapters::Sequel)
        allow(sequel_adapter).to receive(:get_base_class).and_return(sequel_model_class)
        allow(Tidewave::DatabaseAdapter).to receive(:current).and_return(sequel_adapter)

        # Mock Object.const_source_location for named model
        allow(Object).to receive(:const_source_location).with("Account").and_return([ "/app/models/account.rb", 1 ])
      end

      it "filters out anonymous Sequel models and includes only named models" do
        result = described_class.new.call

        # Should include named model
        expect(result).to include("Account")
        # Should NOT include anonymous Sequel model
        expect(result).not_to include("Sequel::_Model(:accounts)")
      end
    end
  end
end
