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
  def setup
    @tool = Tidewave::Tools::GetModels.new
  end

  def test_validate_and_call_returns_models_with_source_locations
    eager_loaded = false
    application = Object.new
    application.define_singleton_method(:eager_load!) { eager_loaded = true }

    adapter = Object.new
    adapter.define_singleton_method(:get_models) do
      [ TidewaveGetModelsUser, TidewaveGetModelsPost, TidewaveGetModelsComment ]
    end

    Rails.stub(:application, application) do
      Rails.stub(:root, Pathname.pwd) do
        Tidewave::DatabaseAdapter.stub(:current, adapter) do
          result = @tool.validate_and_call({})

          assert_includes result, "* TidewaveGetModelsUser at test/tools/get_models_test.rb:"
          assert_includes result, "* TidewaveGetModelsPost at test/tools/get_models_test.rb:"
          assert_includes result, "* TidewaveGetModelsComment at test/tools/get_models_test.rb:"
          assert_equal true, eager_loaded
        end
      end
    end
  end

  def test_validate_and_call_handles_models_without_source_location
    adapter = Object.new
    adapter.define_singleton_method(:get_models) do
      [ TidewaveGetModelsUser, Struct.new(:name).new("TidewaveMissingSourceModel") ]
    end

    original_const_source_location = Object.method(:const_source_location)

    Rails.stub(:application, nil) do
      Rails.stub(:root, Pathname.pwd) do
        Object.stub(:const_source_location, lambda { |name|
          name == "TidewaveMissingSourceModel" ? nil : original_const_source_location.call(name)
        }) do
          Tidewave::DatabaseAdapter.stub(:current, adapter) do
            result = @tool.validate_and_call({})

            assert_includes result, "* TidewaveGetModelsUser at test/tools/get_models_test.rb:"
            assert_includes result, "* TidewaveMissingSourceModel"
          end
        end
      end
    end
  end
end
