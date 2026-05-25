# frozen_string_literal: true

require "test_helper"

class TidewaveExecuteSqlQueryTest < Minitest::Test
  def setup
    @tool = Tidewave::Tools::ExecuteSqlQuery.new
  end

  def test_validate_and_call_returns_adapter_result
    adapter = Object.new
    adapter.define_singleton_method(:execute_query) do |query, arguments|
      {
        columns: [ "id", "name" ],
        rows: [ [ 1, "test" ] ],
        row_count: 1,
        adapter: "SQLite",
        database: ":memory:",
        query: query,
        arguments: arguments
      }
    end

    Tidewave::DatabaseAdapter.stub(:current, adapter) do
      result = @tool.validate_and_call({ "query" => "SELECT 1 as id, 'test' as name" })

      assert_equal [ "id", "name" ], result[:columns]
      assert_equal [ [ 1, "test" ] ], result[:rows]
      assert_equal 1, result[:row_count]
      assert_equal [], result[:arguments]
    end
  end

  def test_validate_and_call_passes_query_arguments
    adapter = Object.new
    adapter.define_singleton_method(:execute_query) do |query, arguments|
      {
        query: query,
        arguments: arguments
      }
    end

    Tidewave::DatabaseAdapter.stub(:current, adapter) do
      result = @tool.validate_and_call({
        "query" => "SELECT ? as id, ? as name",
        "arguments" => [ 42, "dynamic" ]
      })

      assert_equal "SELECT ? as id, ? as name", result[:query]
      assert_equal [ 42, "dynamic" ], result[:arguments]
    end
  end

  def test_validate_and_call_requires_query
    error = assert_raises(ArgumentError) do
      @tool.validate_and_call({})
    end

    assert_equal "Invalid arguments: missing required property 'query'", error.message
  end
end
