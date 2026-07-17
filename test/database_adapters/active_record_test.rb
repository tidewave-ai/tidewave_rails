# frozen_string_literal: true

require "test_helper"
require "tidewave/database_adapters/active_record"

class TidewaveDatabaseAdaptersActiveRecordTest < TidewaveActiveRecordTestCase
  def setup
    super
    @adapter = Tidewave::DatabaseAdapters::ActiveRecord.new
  end

  def test_execute_query_formats_results_without_arguments
    response = @adapter.execute_query("SELECT 1 as id, 'test' as name")

    assert_equal [ "id", "name" ], response[:columns]
    assert_equal [ [ 1, "test" ] ], response[:rows]
    assert_equal 1, response[:row_count]
    assert_equal "SQLite", response[:adapter]
    assert_equal ":memory:", response[:database]
  end

  def test_execute_query_passes_arguments
    response = @adapter.execute_query("SELECT ? as id, ? as name", [ 42, "dynamic" ])

    assert_equal [ [ 42, "dynamic" ] ], response[:rows]
    assert_equal 1, response[:row_count]
  end

  def test_execute_query_limits_rows_to_fifty
    rows_table = "active_record_rows"

    ActiveRecord::Base.connection.create_table(rows_table) do |table|
      table.integer :number
      table.string :name
    end

    60.times do |index|
      ActiveRecord::Base.connection.execute("INSERT INTO #{rows_table} (number, name) VALUES (#{index + 1}, 'Row #{index + 1}')")
    end

    response = @adapter.execute_query("SELECT number, name FROM #{rows_table} ORDER BY number")

    assert_equal 60, response[:row_count]
    assert_equal 50, response[:rows].length
    assert_equal [ 1, "Row 1" ], response[:rows].first
    assert_equal [ 50, "Row 50" ], response[:rows].last
  end

  def test_execute_query_reraises_adapter_errors
    assert_raises(ActiveRecord::StatementInvalid) do
      @adapter.execute_query("INVALID SQL SYNTAX")
    end
  end
end
