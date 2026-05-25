# frozen_string_literal: true

require "active_record"
require "test_helper"
require "tidewave/database_adapters/active_record"

class TidewaveDatabaseAdaptersActiveRecordTest < Minitest::Test
  Result = Struct.new(:columns, :rows)

  def setup
    @adapter = Tidewave::DatabaseAdapters::ActiveRecord.new
    Rails.env = "test"
    Rails.configuration = Struct.new(:database_configuration).new({
      "test" => { "database" => ":memory:" }
    })
  end

  def test_execute_query_formats_results_without_arguments
    result = Result.new([ "id", "name" ], [ [ 1, "test" ] ])
    connection = build_connection(result)

    response = with_connection(connection) do
      @adapter.execute_query("SELECT 1 as id, 'test' as name")
    end

    assert_equal [ "id", "name" ], response[:columns]
    assert_equal [ [ 1, "test" ] ], response[:rows]
    assert_equal 1, response[:row_count]
    assert_equal "SQLite", response[:adapter]
    assert_equal ":memory:", response[:database]
  end

  def test_execute_query_passes_arguments
    result = Result.new([ "id", "name" ], [ [ 42, "dynamic" ] ])
    captured_args = nil
    connection = build_connection(result) { |args| captured_args = args }

    response = with_connection(connection) do
      @adapter.execute_query("SELECT ? as id, ? as name", [ 42, "dynamic" ])
    end

    assert_equal [ "SELECT ? as id, ? as name", "SQL", [ 42, "dynamic" ] ], captured_args
    assert_equal [ [ 42, "dynamic" ] ], response[:rows]
    assert_equal 1, response[:row_count]
  end

  def test_execute_query_limits_rows_to_fifty
    rows = (1..60).map { |index| [ index, "Row #{index}" ] }
    result = Result.new([ "id", "name" ], rows)
    connection = build_connection(result)

    response = with_connection(connection) do
      @adapter.execute_query("SELECT * FROM rows")
    end

    assert_equal 60, response[:row_count]
    assert_equal 50, response[:rows].length
    assert_equal [ 1, "Row 1" ], response[:rows].first
    assert_equal [ 50, "Row 50" ], response[:rows].last
  end

  def test_execute_query_reraises_adapter_errors
    error = ActiveRecord::StatementInvalid.new("INVALID SQL SYNTAX")
    connection = Object.new
    connection.define_singleton_method(:adapter_name) { "SQLite" }
    connection.define_singleton_method(:exec_query) { |_query, *_args| raise error }

    raised = assert_raises(ActiveRecord::StatementInvalid) do
      with_connection(connection) do
        @adapter.execute_query("INVALID SQL SYNTAX")
      end
    end

    assert_same error, raised
  end

  private

  def build_connection(result)
    connection = Object.new
    connection.define_singleton_method(:adapter_name) { "SQLite" }
    connection.define_singleton_method(:exec_query) do |*args|
      yield(args) if block_given?
      result
    end
    connection
  end

  def with_connection(connection, &block)
    ActiveRecord::Base.stub(:connection, connection, &block)
  end
end
