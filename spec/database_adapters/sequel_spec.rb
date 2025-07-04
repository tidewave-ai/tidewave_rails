# frozen_string_literal: true

require "rails_helper"
require "tidewave/database_adapters/sequel"

describe Tidewave::DatabaseAdapters::Sequel do
  before do
    # Create Sequel module and classes for testing
    unless defined?(::Sequel)
      sequel_module = Module.new

      # Define Model class
      model_class = Class.new do
        def self.db
          # This will be stubbed in tests
        end

        def self.descendants
          []
        end
      end

      sequel_module.const_set(:Model, model_class)
      sequel_module.const_set(:Database, Class.new)
      sequel_module.const_set(:Dataset, Class.new)

      Object.const_set(:Sequel, sequel_module)
    end
  end
  let(:adapter) { described_class.new }

  describe "#execute_query" do
    let(:database) { double("Sequel::Database") }
    let(:dataset) { double("Sequel::Dataset") }
    let(:row_count) { 60 }
    let(:rows) { row_count.times.map { |i| { id: i, name: "Test #{i}" } } }

    before do
      allow(::Sequel::Model).to receive(:db).and_return(database)
      allow(database).to receive(:adapter_scheme).and_return(:postgresql)
      allow(database).to receive(:opts).and_return({ database: "test_database" })
    end

    context "with a simple query without arguments" do
      let(:query) { "SELECT * FROM users" }

      it "returns the first 50 rows of the query" do
        expect(database).to receive(:fetch).with(query).and_return(dataset)
        expect(dataset).to receive(:all).and_return(rows)

        response = adapter.execute_query(query)

        expect(response).to eq({
          columns: [ "id", "name" ],
          rows: rows.first(50).map(&:values),
          row_count: row_count,
          adapter: "POSTGRESQL",
          database: "test_database"
        })
      end

      context 'with a row_count smaller than the result limit' do
        let(:row_count) { 10 }
        let(:rows) { row_count.times.map { |i| { id: i, name: "Test #{i}" } } }

        it "returns all rows" do
          expect(database).to receive(:fetch).with(query).and_return(dataset)
          expect(dataset).to receive(:all).and_return(rows)

          response = adapter.execute_query(query)

          expect(response).to eq({
            columns: [ "id", "name" ],
            rows: rows.map(&:values),
            row_count: row_count,
            adapter: "POSTGRESQL",
            database: "test_database"
          })
        end
      end
    end

    context "with query arguments" do
      let(:query) { "SELECT * FROM users WHERE id = ?" }
      let(:arguments) { [ 1 ] }

      it "passes the arguments to the fetch method" do
        expect(database).to receive(:fetch).with(query, *arguments).and_return(dataset)
        expect(dataset).to receive(:all).and_return([])

        adapter.execute_query(query, arguments)
      end
    end

    context "with empty result set" do
      let(:query) { "SELECT * FROM users WHERE id = -1" }

      it "handles empty results gracefully" do
        expect(database).to receive(:fetch).with(query).and_return(dataset)
        expect(dataset).to receive(:all).and_return([])

        response = adapter.execute_query(query)

        expect(response).to eq({
          columns: [],
          rows: [],
          row_count: 0,
          adapter: "POSTGRESQL",
          database: "test_database"
        })
      end
    end
  end

  describe "#get_models" do
    let(:user_model) { double("User", name: "User") }
    let(:post_model) { double("Post", name: "Post") }
    let(:comment_model) { double("Comment", name: "Comment") }

    let(:models) { [ user_model, post_model, comment_model ] }

    let(:user_associations) { { posts: { type: :one_to_many }, profile: { type: :one_to_one } } }
    let(:post_associations) { { user: { type: :many_to_one } } }
    let(:comment_associations) { {} }

    before do
      # Mock Rails.application.eager_load!
      allow(Rails.application).to receive(:eager_load!)

      # Mock Sequel::Model.descendants
      allow(::Sequel::Model).to receive(:descendants).and_return(models)

      # Set up the associations for each model
      allow(user_model).to receive(:association_reflections).and_return(user_associations)
      allow(post_model).to receive(:association_reflections).and_return(post_associations)
      allow(comment_model).to receive(:association_reflections).and_return(comment_associations)
    end

    it "returns all models with all their relationships" do
      expected_response = [
        {
          name: "User",
          relationships: [
            { name: :posts, type: :one_to_many },
            { name: :profile, type: :one_to_one }
          ]
        },
        {
          name: "Post",
          relationships: [
            { name: :user, type: :many_to_one }
          ]
        },
        {
          name: "Comment",
          relationships: []
        }
      ].to_json

      expect(adapter.get_models).to eq(expected_response)
    end
  end

  describe "#adapter_name" do
    it "returns the Sequel adapter name" do
      database = double("Sequel::Database")
      allow(::Sequel::Model).to receive(:db).and_return(database)
      allow(database).to receive(:adapter_scheme).and_return(:postgresql)

      expect(adapter.adapter_name).to eq("POSTGRESQL")
    end
  end

  describe "#database_name" do
    let(:database) { double("Sequel::Database") }

    before do
      allow(::Sequel::Model).to receive(:db).and_return(database)
    end

    context "with PostgreSQL database" do
      it "returns the database name" do
        allow(database).to receive(:adapter_scheme).and_return(:postgresql)
        allow(database).to receive(:opts).and_return({ database: "postgres_db" })

        expect(adapter.database_name).to eq("postgres_db")
      end
    end

    context "with MySQL database" do
      it "returns the database name" do
        allow(database).to receive(:adapter_scheme).and_return(:mysql2)
        allow(database).to receive(:opts).and_return({ database: "mysql_db" })

        expect(adapter.database_name).to eq("mysql_db")
      end
    end

    context "with SQLite database" do
      it "returns the database name" do
        allow(database).to receive(:adapter_scheme).and_return(:sqlite)
        allow(database).to receive(:opts).and_return({ database: "sqlite_db" })

        expect(adapter.database_name).to eq("sqlite_db")
      end
    end

    context "with unknown database" do
      it "returns unknown" do
        allow(database).to receive(:adapter_scheme).and_return(:unknown)
        allow(database).to receive(:opts).and_return({})

        expect(adapter.database_name).to eq("unknown")
      end
    end
  end
end
