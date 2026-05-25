# frozen_string_literal: true

require "test_helper"
require "tidewave/configuration"
require "tidewave/database_adapters/active_record"
require "tidewave/database_adapters/sequel"

class TidewaveDatabaseAdapterTest < Minitest::Test
  def teardown
    reset_current_adapter
  end

  def test_current_returns_same_instance
    set_preferred_orm(:active_record)

    adapter1 = Tidewave::DatabaseAdapter.current
    adapter2 = Tidewave::DatabaseAdapter.current

    assert_same adapter1, adapter2
  end

  def test_create_adapter_returns_active_record_adapter
    set_preferred_orm(:active_record)

    adapter = Tidewave::DatabaseAdapter.create_adapter

    assert_instance_of Tidewave::DatabaseAdapters::ActiveRecord, adapter
  end

  def test_create_adapter_returns_sequel_adapter
    set_preferred_orm(:sequel)

    adapter = Tidewave::DatabaseAdapter.create_adapter

    assert_instance_of Tidewave::DatabaseAdapters::Sequel, adapter
  end

  def test_create_adapter_raises_for_unknown_orm
    set_preferred_orm(:unknown)

    error = assert_raises(RuntimeError) do
      Tidewave::DatabaseAdapter.create_adapter
    end

    assert_equal "Unknown preferred ORM: unknown", error.message
  end

  private

  def set_preferred_orm(orm)
    tidewave = Struct.new(:preferred_orm).new(orm)
    config = Struct.new(:tidewave).new(tidewave)
    Rails.application = Struct.new(:config).new(config)
  end

  def reset_current_adapter
    singleton = Tidewave::DatabaseAdapter.singleton_class
    singleton.remove_instance_variable(:@current) if singleton.instance_variable_defined?(:@current)
  end
end
