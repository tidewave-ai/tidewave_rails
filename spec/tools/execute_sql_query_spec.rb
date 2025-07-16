# frozen_string_literal: true

require "rails_helper"

describe Tidewave::Tools::ExecuteSqlQuery do
  describe 'tags' do
    it 'does not include the file_system_tool tag' do
      expect(described_class.tags).not_to include(:file_system_tool)
    end
  end
  describe ".tool_name" do
    it "returns the correct tool name" do
      expect(described_class.tool_name).to eq("execute_sql_query")
    end
  end

  describe ".description" do
    it "returns the correct description" do
      expect(described_class.description).to eq(
        <<~DESCRIPTION
          Executes the given SQL query against the database connection.
          Returns the result as a Ruby data structure.

          Note that the output is limited to 50 rows at a time. If you need to see more, perform additional calls
          using LIMIT and OFFSET in the query. If you know that only specific columns are relevant,
          only include those in the SELECT clause.

          You can use this tool to select user data, manipulate entries, and introspect the application data domain.
          Always ensure to use the correct SQL commands for the database you are using.

          For PostgreSQL, use $1, $2, etc. for parameter placeholders.
          For MySQL, use ? for parameter placeholders.
        DESCRIPTION
      )
    end
  end

  describe ".input_schema_to_json" do
    let(:expected_input_schema) do
      {
        properties: {
          query: {
            type: "string",
            description: "The SQL query to execute. For PostgreSQL, use $1, $2 placeholders. For MySQL, use ? placeholders."
          },
          arguments: {
            type: "array",
            items: {},
            description: "The arguments to pass to the query. The query must contain corresponding parameter placeholders."
          }
        },
        required: [ "query" ],
        type: "object"
      }
    end

    it "returns the correct input schema" do
      expect(described_class.input_schema_to_json).to eq(expected_input_schema)
    end
  end

  describe "#call" do
    context "with a simple query without arguments" do
      let(:query) { "SELECT 1 as id, 'test' as name" }

      it "returns the query result" do
        response = described_class.new.call(query: query)

        expect(response).to include(
          columns: [ "id", "name" ],
          rows: [ [ 1, "test" ] ],
          row_count: 1,
          adapter: "SQLite",
          database: ":memory:"
        )
      end
    end

    context "with a query returning multiple rows" do
      let(:query) do
        <<~SQL
          SELECT
            row_number() OVER () as id,
            'User ' || row_number() OVER () as name
          FROM (
            SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5
          )
        SQL
      end

      it "returns all rows" do
        response = described_class.new.call(query: query)

        expect(response).to include(
          columns: [ "id", "name" ],
          row_count: 5,
          adapter: "SQLite"
        )
        expect(response[:rows]).to eq([
          [ 1, "User 1" ],
          [ 2, "User 2" ],
          [ 3, "User 3" ],
          [ 4, "User 4" ],
          [ 5, "User 5" ]
        ])
      end
    end

    context "with query arguments" do
      let(:query) { "SELECT ? as id, ? as name" }
      let(:arguments) { [ 42, "dynamic" ] }

      it "passes the arguments to the query" do
        response = described_class.new.call(query: query, arguments: arguments)

        expect(response).to include(
          columns: [ "id", "name" ],
          rows: [ [ 42, "dynamic" ] ],
          row_count: 1
        )
      end
    end

    context "when the query execution fails" do
      let(:query) { "INVALID SQL SYNTAX" }

      it "raises an error" do
        expect { described_class.new.call(query: query) }.to raise_error(ActiveRecord::StatementInvalid)
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
        response = described_class.new.call(query: query)

        expect(response[:row_count]).to eq(60)
        expect(response[:rows].length).to eq(50)
        expect(response[:rows].first).to eq([ 1, "Row 1" ])
        expect(response[:rows].last).to eq([ 50, "Row 50" ])
      end
    end
  end
end
