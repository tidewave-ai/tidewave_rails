# frozen_string_literal: true

require "rails_helper"
require "sequel"
require "tidewave/database_adapters/sequel"

describe Tidewave::DatabaseAdapters::Sequel do
  let(:db) { Sequel.sqlite }
  let(:adapter) { described_class.new }

  # Mock Sequel::Model to use our test database
  before do
    allow(::Sequel::Model).to receive(:db).and_return(db)

    # Create test tables
    db.create_table? :users do
      primary_key :id
      String :name
    end

    db.create_table? :posts do
      primary_key :id
      String :title
      String :content
    end

    # Insert test data
    db[:users].insert(id: 1, name: "test")
    db[:users].insert(id: 2, name: "user2")

    50.times do |i|
      db[:posts].insert(id: i + 1, title: "Post #{i + 1}", content: "Content #{i + 1}")
    end

    # Insert 10 more posts to test the 50 row limit
    10.times do |i|
      db[:posts].insert(id: i + 51, title: "Post #{i + 51}", content: "Content #{i + 51}")
    end
  end

  after do
    db.drop_table? :users
    db.drop_table? :posts
  end

  describe "#execute_query" do
    context "with a simple query without arguments" do
      let(:query) { "SELECT 1 as id, 'test' as name" }

      it "returns the query result" do
        response = adapter.execute_query(query)

        expect(response).to include(
          columns: [ "id", "name" ],
          rows: [ [ 1, "test" ] ],
          row_count: 1,
          adapter: "SQLITE",
          database: nil
        )
      end
    end

    context "with query arguments" do
      let(:query) { "SELECT ? as id, ? as name" }
      let(:arguments) { [ 42, "dynamic" ] }

      it "passes the arguments to the query" do
        response = adapter.execute_query(query, arguments)

        expect(response).to include(
          columns: [ "id", "name" ],
          rows: [ [ 42, "dynamic" ] ],
          row_count: 1
        )
      end
    end

    context "with a query returning more than 50 rows" do
      let(:query) { "SELECT * FROM posts ORDER BY id" }

      it "limits results to 50 rows" do
        response = adapter.execute_query(query)

        expect(response[:row_count]).to eq(60)
        expect(response[:rows].length).to eq(50)
        expect(response[:columns]).to eq([ "id", "title", "content" ])
        expect(response[:rows].first).to eq([ 1, "Post 1", "Content 1" ])
        expect(response[:rows].last).to eq([ 50, "Post 50", "Content 50" ])
      end
    end

    context "when the query execution fails" do
      let(:query) { "SELECT * FROM nonexistent_table" }

      it "raises an error" do
        expect { adapter.execute_query(query) }.to raise_error(Sequel::DatabaseError)
      end
    end

    context "with empty result set" do
      let(:query) { "SELECT * FROM users WHERE id = -1" }

      it "handles empty results gracefully" do
        response = adapter.execute_query(query)

        expect(response).to include(
          columns: [],
          rows: [],
          row_count: 0,
          adapter: "SQLITE",
          database: nil
        )
      end
    end

    context "with existing data" do
      let(:query) { "SELECT * FROM users ORDER BY id" }

      it "returns actual data from the database" do
        response = adapter.execute_query(query)

        expect(response).to include(
          columns: [ "id", "name" ],
          rows: [ [ 1, "test" ], [ 2, "user2" ] ],
          row_count: 2,
          adapter: "SQLITE",
          database: nil
        )
      end
    end
  end

  describe "#get_base_class" do
    it "returns the Sequel::Model base class" do
      result = adapter.get_base_class

      expect(result).to eq(::Sequel::Model)
    end
  end

  describe "#get_models" do
    it "filters out anonymous Sequel models" do
      # Mock Sequel models including anonymous ones
      account_model = double("Account", name: "Account")
      user_model = double("User", name: "User")
      anonymous_model1 = double("AnonymousModel1", name: "Sequel::_Model(:accounts)")
      anonymous_model2 = double("AnonymousModel2", name: "Sequel::_Model(:users)")

      allow(::Sequel::Model).to receive(:descendants).and_return([
        account_model,
        user_model,
        anonymous_model1,
        anonymous_model2
      ])

      result = adapter.get_models

      expect(result).to include(account_model, user_model)
      expect(result).not_to include(anonymous_model1, anonymous_model2)
    end

    it "handles models with nil names gracefully" do
      named_model = double("NamedModel", name: "Account")
      nil_name_model = double("NilNameModel", name: nil)

      allow(::Sequel::Model).to receive(:descendants).and_return([
        named_model,
        nil_name_model
      ])

      result = adapter.get_models

      expect(result).to include(named_model, nil_name_model)
    end
  end
end
