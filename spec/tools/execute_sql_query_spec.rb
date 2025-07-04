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
    let(:database_adapter) { instance_double("Tidewave::DatabaseAdapter") }
    let(:expected_response) do
      {
        columns: [ "id", "name" ],
        rows: [ [ 1, "Test 1" ], [ 2, "Test 2" ] ],
        row_count: 2,
        adapter: "PostgreSQL",
        database: ":memory:"
      }
    end

    before do
      allow(Tidewave::DatabaseAdapter).to receive(:current).and_return(database_adapter)
    end

    context "with a simple query without arguments" do
      let(:query) { "SELECT * FROM users" }

      it "delegates to the database adapter" do
        expect(database_adapter).to receive(:execute_query).with(query, []).and_return(expected_response)

        response = described_class.new.call(query: query)

        expect(response).to eq(expected_response)
      end
    end

    context "with query arguments" do
      let(:query) { "SELECT * FROM users WHERE id = $1" }
      let(:arguments) { [ 1 ] }

      it "passes the arguments to the database adapter" do
        expect(database_adapter).to receive(:execute_query).with(query, arguments).and_return(expected_response)

        described_class.new.call(query: query, arguments: arguments)
      end
    end

    context "when the query execution fails" do
      let(:query) { "INVALID SQL" }
      let(:error_message) { "syntax error" }

      it "raises an error" do
        expect(database_adapter).to receive(:execute_query).and_raise(StandardError, error_message)

        expect { described_class.new.call(query: query) }.to raise_error(StandardError, error_message)
      end
    end
  end
end
