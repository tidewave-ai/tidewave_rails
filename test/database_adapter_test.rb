# frozen_string_literal: true

require "test_helper"
require "tidewave/database_adapters/active_record"
require "tidewave/database_adapters/sequel"

class TidewaveDatabaseAdapterTest < Minitest::Test
  def test_for_returns_active_record_adapter
    adapter = Tidewave::DatabaseAdapter.for(:active_record)

    assert_instance_of Tidewave::DatabaseAdapters::ActiveRecord, adapter
  end

  def test_for_returns_sequel_adapter
    adapter = Tidewave::DatabaseAdapter.for(:sequel)

    assert_instance_of Tidewave::DatabaseAdapters::Sequel, adapter
  end

  def test_for_returns_a_new_instance_each_time
    adapter1 = Tidewave::DatabaseAdapter.for(:active_record)
    adapter2 = Tidewave::DatabaseAdapter.for(:active_record)

    refute_same adapter1, adapter2
  end

  def test_for_raises_for_unknown_orm
    error = assert_raises(RuntimeError) do
      Tidewave::DatabaseAdapter.for(:unknown)
    end

    assert_equal "Unknown preferred ORM: unknown", error.message
  end

  def test_normalize_result_rows_escapes_binary_prefix_in_text
    rows = Tidewave::DatabaseAdapter.new.send(
      :normalize_result_rows,
      [ [ "base64:Y2Fmnw==", "base64::literal" ] ]
    )

    assert_equal [ [ "base64::Y2Fmnw==", "base64:::literal" ] ], rows
  end

  def test_normalize_result_rows_encodes_strings_without_a_utf8_converter
    value = "encoded text".dup.force_encoding(Encoding::UTF_7)

    rows = Tidewave::DatabaseAdapter.new.send(:normalize_result_rows, [ [ value ] ])

    assert_equal [ [ "base64:ZW5jb2RlZCB0ZXh0" ] ], rows
  end
end
