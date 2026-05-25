# frozen_string_literal: true

require "test_helper"

TIDEWAVE_GET_SOURCE_LOCATION_MODULE_LINE = __LINE__ + 1
class TidewaveGetSourceLocationTestModule
  TIDEWAVE_GET_SOURCE_LOCATION_FOO_LINE = __LINE__ + 1
  def self.foo
    "foo"
  end

  TIDEWAVE_GET_SOURCE_LOCATION_BAR_LINE = __LINE__ + 1
  def bar
    "bar"
  end
end

TIDEWAVE_GET_SOURCE_LOCATION_BAZ_LINE = __LINE__ + 1
TidewaveGetSourceLocationTestModule::BAZ = 123

class TidewaveGetSourceLocationTest < Minitest::Test
  def setup
    @tool = Tidewave::Tools::GetSourceLocation.new
  end

  def test_validate_and_call_returns_module_source_location
    result = @tool.validate_and_call({ "reference" => "TidewaveGetSourceLocationTestModule" })

    assert_equal "test/tools/get_source_location_test.rb:#{TIDEWAVE_GET_SOURCE_LOCATION_MODULE_LINE}", result
  end

  def test_validate_and_call_returns_constant_source_location
    result = @tool.validate_and_call({ "reference" => "TidewaveGetSourceLocationTestModule::BAZ" })

    assert_equal "test/tools/get_source_location_test.rb:#{TIDEWAVE_GET_SOURCE_LOCATION_BAZ_LINE}", result
  end

  def test_validate_and_call_returns_class_method_source_location
    result = @tool.validate_and_call({ "reference" => "TidewaveGetSourceLocationTestModule.foo" })

    assert_equal(
      "test/tools/get_source_location_test.rb:#{TidewaveGetSourceLocationTestModule::TIDEWAVE_GET_SOURCE_LOCATION_FOO_LINE}",
      result
    )
  end

  def test_validate_and_call_returns_instance_method_source_location
    result = @tool.validate_and_call({ "reference" => "TidewaveGetSourceLocationTestModule#bar" })

    assert_equal(
      "test/tools/get_source_location_test.rb:#{TidewaveGetSourceLocationTestModule::TIDEWAVE_GET_SOURCE_LOCATION_BAR_LINE}",
      result
    )
  end

  def test_validate_and_call_returns_package_location
    result = @tool.validate_and_call({ "reference" => "dep:rack" })

    assert_includes result, "rack"
    assert File.directory?(result)
  end

  def test_validate_and_call_raises_when_reference_is_not_found
    error = assert_raises(NameError) do
      @tool.validate_and_call({ "reference" => "NonExistentModule" })
    end

    assert_equal "could not find source location for NonExistentModule", error.message
  end

  def test_validate_and_call_raises_when_reference_is_invalid
    error = assert_raises(NameError) do
      @tool.validate_and_call({ "reference" => "1+2" })
    end

    assert_equal "wrong constant name 1+2", error.message
  end

  def test_validate_and_call_raises_when_package_is_not_found
    error = assert_raises(RuntimeError) do
      @tool.validate_and_call({ "reference" => "dep:non_existent_package_xyz" })
    end

    assert_equal(
      "Package non_existent_package_xyz not found. Check your Gemfile for available packages.",
      error.message
    )
  end
end
