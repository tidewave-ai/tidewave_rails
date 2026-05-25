# frozen_string_literal: true

require "pathname"
require "test_helper"

class TidewaveGetModelsUser
end

class TidewaveGetModelsPost
end

class TidewaveGetModelsComment
end

class TidewaveGetModelsTest < Minitest::Test
  def test_validate_and_call_returns_models_with_source_locations
    eager_loaded = false
    adapter = Object.new
    adapter.define_singleton_method(:get_models) do
      [ TidewaveGetModelsUser, TidewaveGetModelsPost, TidewaveGetModelsComment ]
    end

    Tidewave::DatabaseAdapter.stub(:for, adapter) do
      tool = Tidewave::Tools::GetModels.new(
        root: Pathname.pwd,
        orm_adapter: :active_record,
        before_reload: -> { eager_loaded = true }
      )

      result = tool.validate_and_call({})

      assert_includes result, "* TidewaveGetModelsUser at test/tools/get_models_test.rb:"
      assert_includes result, "* TidewaveGetModelsPost at test/tools/get_models_test.rb:"
      assert_includes result, "* TidewaveGetModelsComment at test/tools/get_models_test.rb:"
      assert_equal true, eager_loaded
    end
  end

  def test_validate_and_call_handles_models_without_source_location
    adapter = Object.new
    adapter.define_singleton_method(:get_models) do
      [ TidewaveGetModelsUser, Struct.new(:name).new("TidewaveMissingSourceModel") ]
    end
    original_const_source_location = Object.method(:const_source_location)

    Tidewave::DatabaseAdapter.stub(:for, adapter) do
      tool = Tidewave::Tools::GetModels.new(
        root: Pathname.pwd,
        orm_adapter: :active_record
      )

      result = Object.stub(:const_source_location, lambda { |name|
        name == "TidewaveMissingSourceModel" ? nil : original_const_source_location.call(name)
      }) do
        tool.validate_and_call({})
      end

      assert_includes result, "* TidewaveGetModelsUser at test/tools/get_models_test.rb:"
      assert_includes result, "* TidewaveMissingSourceModel"
    end
  end

  def test_definition_is_nil_when_orm_adapter_is_missing
    tool = Tidewave::Tools::GetModels.new(root: Pathname.pwd)

    assert_nil tool.definition
  end
end
