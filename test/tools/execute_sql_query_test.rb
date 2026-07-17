# frozen_string_literal: true

require "test_helper"

class TidewaveExecuteSqlQueryTest < TidewaveActiveRecordTestCase
  def test_validate_and_call_returns_inspected_adapter_result
    tool = Tidewave::Tools::ExecuteSqlQuery.new(orm_adapter: :active_record)
    result = tool.validate_and_call({ "query" => "SELECT 1 as id, 'test' as name" })

    assert_includes result, ':columns=>["id", "name"]'
    assert_includes result, ':rows=>[[1, "test"]]'
  end

  def test_validate_and_call_reports_truncated_rows
    tool = Tidewave::Tools::ExecuteSqlQuery.new(orm_adapter: :active_record)
    result = tool.validate_and_call({
      "query" => <<~SQL
        WITH RECURSIVE numbers(number) AS (
          SELECT 1
          UNION ALL
          SELECT number + 1 FROM numbers WHERE number < 60
        )
        SELECT number FROM numbers
      SQL
    })

    assert_includes result, "Query returned 60 rows. Only the first 50 rows are included in the result."
    assert_includes result, "Use your database's pagination syntax, such as LIMIT + OFFSET, to show more rows if applicable."
    assert_includes result, "[50]"
    refute_includes result, "[51]"
  end

  def test_validate_and_call_passes_query_arguments
    tool = Tidewave::Tools::ExecuteSqlQuery.new(orm_adapter: :active_record)
    result = tool.validate_and_call({
      "query" => "SELECT ? as id, ? as name",
      "arguments" => [ 42, "dynamic" ]
    })

    assert_includes result, ':rows=>[[42, "dynamic"]]'
  end

  def test_validate_and_call_inspects_invalid_utf8_values
    invalid_utf8 = "caf\x9F"
    invalid_utf8_hex = invalid_utf8.unpack1("H*")
    ActiveRecord::Base.connection.execute("CREATE TABLE tool_invalid_utf8 (name text)")
    ActiveRecord::Base.connection.execute(
      "INSERT INTO tool_invalid_utf8 VALUES (CAST(X'#{invalid_utf8_hex}' AS TEXT))"
    )
    tool = Tidewave::Tools::ExecuteSqlQuery.new(orm_adapter: :active_record)

    result = tool.validate_and_call({ "query" => "SELECT name FROM tool_invalid_utf8" })

    assert_includes result, invalid_utf8.inspect
    assert_predicate result, :valid_encoding?
  end

  def test_validate_and_call_inspects_binary_values
    binary_value_with_non_utf8_byte = "caf\x9F".b
    binary_value_hex = binary_value_with_non_utf8_byte.unpack1("H*")
    ActiveRecord::Base.connection.execute("CREATE TABLE tool_binary (data blob)")
    ActiveRecord::Base.connection.execute("INSERT INTO tool_binary VALUES (X'#{binary_value_hex}')")
    tool = Tidewave::Tools::ExecuteSqlQuery.new(orm_adapter: :active_record)

    result = tool.validate_and_call({ "query" => "SELECT data FROM tool_binary" })

    assert_includes result, binary_value_with_non_utf8_byte.inspect
    assert_predicate result, :valid_encoding?
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
