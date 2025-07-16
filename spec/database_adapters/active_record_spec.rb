# frozen_string_literal: true

require "rails_helper"
require "tidewave/database_adapters/active_record"

describe Tidewave::DatabaseAdapters::ActiveRecord do
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
          adapter: "SQLite",
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
        expect { adapter.execute_query(query) }.to raise_error(ActiveRecord::StatementInvalid)
      end
    end
  end

  describe "#get_base_class" do
    it "returns the ActiveRecord::Base class" do
      result = adapter.get_base_class

      expect(result).to eq(::ActiveRecord::Base)
    end
  end
end
