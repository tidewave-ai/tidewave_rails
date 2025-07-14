# frozen_string_literal: true

require "rails_helper"
require "tidewave/database_adapters/sequel"

# Create mock Sequel classes for testing when Sequel gem is not available
unless defined?(::Sequel)
  sequel_module = Module.new

  model_class = Class.new do
    def self.db
      @db ||= Sequel::Database.new
    end

    def self.descendants
      []
    end

    def self.name
      "SequelTestModel"
    end
  end

  database_class = Class.new do
    def initialize
      @results = []
    end

    def fetch(query, *args)
      # Return a simple dataset mock
      dataset = Sequel::Dataset.new
      dataset.instance_variable_set(:@results, mock_query_results(query, args))
      dataset
    end

    def adapter_scheme
      :sqlite
    end

    def opts
      { database: ":memory:" }
    end

    private

    def mock_query_results(query, args)
      case query
      when /SELECT 1 as id, 'test' as name/
        [ { id: 1, name: "test" } ]
      when /SELECT \? as id, \? as name/
        [ { id: args[0], name: args[1] } ]
      when /WITH RECURSIVE numbers/
        60.times.map { |i| { id: i + 1, name: "Row #{i + 1}" } }
      when /INVALID SQL SYNTAX/
        raise "Invalid SQL"
      else
        []
      end
    end
  end

  dataset_class = Class.new do
    def all
      @results || []
    end
  end

  sequel_module.const_set(:Model, model_class)
  sequel_module.const_set(:Database, database_class)
  sequel_module.const_set(:Dataset, dataset_class)

  Object.const_set(:Sequel, sequel_module)
end

describe Tidewave::DatabaseAdapters::Sequel do
  let(:adapter) { described_class.new }

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
          database: ":memory:"
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
      let(:query) do
        <<~SQL
          WITH RECURSIVE numbers(n) AS (
            SELECT 1
            UNION ALL
            SELECT n + 1 FROM numbers WHERE n < 60
          )
          SELECT n as id, 'Row ' || n as name FROM numbers
        SQL
      end

      it "limits results to 50 rows" do
        response = adapter.execute_query(query)

        expect(response[:row_count]).to eq(60)
        expect(response[:rows].length).to eq(50)
        expect(response[:rows].first).to eq([ 1, "Row 1" ])
        expect(response[:rows].last).to eq([ 50, "Row 50" ])
      end
    end

    context "when the query execution fails" do
      let(:query) { "INVALID SQL SYNTAX" }

      it "raises an error" do
        expect { adapter.execute_query(query) }.to raise_error(StandardError)
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
          database: ":memory:"
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

  describe "#adapter_name" do
    it "returns the Sequel adapter name" do
      expect(adapter.adapter_name).to eq("SQLITE")
    end
  end

  describe "#database_name" do
    context "with SQLite database" do
      it "returns the database name" do
        expect(adapter.database_name).to eq(":memory:")
      end
    end

    context "with PostgreSQL database" do
      it "returns the database name" do
        db = double("Sequel::Database")
        allow(::Sequel::Model).to receive(:db).and_return(db)
        allow(db).to receive(:adapter_scheme).and_return(:postgresql)
        allow(db).to receive(:opts).and_return({ database: "postgres_db" })

        expect(adapter.database_name).to eq("postgres_db")
      end
    end

    context "with MySQL database" do
      it "returns the database name" do
        db = double("Sequel::Database")
        allow(::Sequel::Model).to receive(:db).and_return(db)
        allow(db).to receive(:adapter_scheme).and_return(:mysql2)
        allow(db).to receive(:opts).and_return({ database: "mysql_db" })

        expect(adapter.database_name).to eq("mysql_db")
      end
    end

    context "with unknown database" do
      it "returns unknown" do
        db = double("Sequel::Database")
        allow(::Sequel::Model).to receive(:db).and_return(db)
        allow(db).to receive(:adapter_scheme).and_return(:unknown)
        allow(db).to receive(:opts).and_return({})

        expect(adapter.database_name).to eq("unknown")
      end
    end
  end
end
