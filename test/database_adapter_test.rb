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
end
