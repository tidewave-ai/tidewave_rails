# frozen_string_literal: true

require "test_helper"

class TidewaveExecuteSqlQueryTest < TidewaveActiveRecordTestCase
  def test_validate_and_call_returns_adapter_result
    tool = Tidewave::Tools::ExecuteSqlQuery.new(orm_adapter: :active_record)
    result = tool.validate_and_call({ "query" => "SELECT 1 as id, 'test' as name" })

    assert_equal [ "id", "name" ], result[:columns]
    assert_equal [ [ 1, "test" ] ], result[:rows]
    assert_equal 1, result[:row_count]
  end

  def test_validate_and_call_passes_query_arguments
    tool = Tidewave::Tools::ExecuteSqlQuery.new(orm_adapter: :active_record)
    result = tool.validate_and_call({
      "query" => "SELECT ? as id, ? as name",
      "arguments" => [ 42, "dynamic" ]
    })

    assert_equal [ [ 42, "dynamic" ] ], result[:rows]
  end

  def test_validate_and_call_requires_query
    tool = Tidewave::Tools::ExecuteSqlQuery.new(orm_adapter: :active_record)

    error = assert_raises(ArgumentError) do
      tool.validate_and_call({})
    end

    assert_equal "Invalid arguments: missing required property 'query'", error.message
  end

  def test_definition_is_nil_when_orm_adapter_is_missing
    tool = Tidewave::Tools::ExecuteSqlQuery.new

    assert_nil tool.definition
  end
end
