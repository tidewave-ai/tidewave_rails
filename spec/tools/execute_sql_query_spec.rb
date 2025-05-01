# frozen_string_literal: true

require "rails_helper"

describe Tidewave::Tools::ExecuteSqlQuery do
  describe '.file_system_tool?' do
    it 'returns nil' do
      expect(described_class.file_system_tool?).to be nil
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
          Executes the given SQL query against the ActiveRecord database connection.
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
    let(:connection) { instance_double("ActiveRecord::ConnectionAdapters::PostgreSQLAdapter") }
    let(:result) { instance_double("ActiveRecord::Result") }
    let(:row_count) { 60 }
    let(:rows) { row_count.times.map { |i| [ i, "Test #{i}" ] } }

    before do
      allow(ActiveRecord::Base).to receive(:connection).and_return(connection)
      allow(connection).to receive(:adapter_name).and_return("PostgreSQL")
      allow(Rails).to receive_message_chain(:configuration, :database_configuration).and_return({
        "test" => {
          "database" => ":memory:"
        }
        })
      allow(result).to receive(:columns).and_return([ "id", "name" ])
      allow(result).to receive(:rows).and_return(rows)
    end

    context "with a simple query without arguments" do
      let(:query) { "SELECT * FROM users" }

      it "returns the first 50 rows of the query" do
        expect(connection).to receive(:exec_query).with(query).and_return(result)

        response = described_class.new.call(query: query)

        expect(response).to eq({
          columns: [ "id", "name" ],
          rows: rows.first(50),
          row_count: row_count,
          adapter: "PostgreSQL",
          database: ":memory:"
        })
      end

      context 'with a row_count smaller than the result limit' do
        let(:row_count) { 10 }
        let(:rows) { row_count.times.map { |i| [ i, "Test #{i}" ] } }

        it "returns the first 50 rows of the query" do
          expect(connection).to receive(:exec_query).with(query).and_return(result)

          response = described_class.new.call(query: query)

          expect(response).to eq({
            columns: [ "id", "name" ],
            rows: rows,
            row_count: row_count,
            adapter: "PostgreSQL",
            database: ":memory:"
          })
        end
      end
    end

    context "with query arguments" do
      let(:query) { "SELECT * FROM users WHERE id = $1" }
      let(:arguments) { [ 1 ] }

      it "passes the arguments to the exec_query method" do
        expect(connection).to receive(:exec_query).with(query, "SQL", arguments).and_return(result)

        described_class.new.call(query: query, arguments: arguments)
      end
    end

    context "when the query execution fails" do
      let(:query) { "INVALID SQL" }
      let(:error_message) { "syntax error" }

      it "raises an error" do
        expect(connection).to receive(:exec_query).and_raise(StandardError, error_message)

        expect { described_class.new.call(query: query) }.to raise_error(StandardError, error_message)
      end
    end
  end
end
