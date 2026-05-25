# frozen_string_literal: true

require "test_helper"

class TidewaveToolTest < Minitest::Test
  def setup
    @tool_class = Class.new(Tidewave::Tool) do
      def definition
        {
          "name" => "sample",
          "description" => "A sample tool.",
          "inputSchema" => {
            "type" => "object",
            "properties" => {
              "name" => {
                "type" => "string"
              },
              "count" => {
                "type" => "integer"
              },
              "enabled" => {
                "type" => "boolean",
                "default" => false
              },
              "tags" => {
                "type" => "array",
                "items" => {}
              },
              "options" => {
                "type" => "object"
              }
            },
            "required" => [ "name", "count" ]
          }
        }
      end

      def call(arguments)
        {
          "content" => [
            {
              "type" => "text",
              "text" => JSON.generate(arguments)
            }
          ]
        }
      end
    end

    @tool = @tool_class.new
  end

  def teardown
    Tidewave::Tool.descendants.delete(@tool_class)
  end

  def test_validate_and_call_returns_tool_result
    result = @tool.validate_and_call({
      "name" => "hello",
      "count" => 2,
      "enabled" => false,
      "tags" => [ "one", 2 ],
      "options" => { "mode" => "fast" }
    })

    assert_equal "text", result.dig("content", 0, "type")
    assert_equal(
      "{\"name\":\"hello\",\"count\":2,\"enabled\":false,\"tags\":[\"one\",2],\"options\":{\"mode\":\"fast\"}}",
      result.dig("content", 0, "text")
    )
  end

  def test_validate_and_call_applies_defaults
    result = @tool.validate_and_call({
      "name" => "hello",
      "count" => 1
    })

    assert_equal "{\"name\":\"hello\",\"count\":1,\"enabled\":false}", result.dig("content", 0, "text")
  end

  def test_validate_and_call_requires_a_hash
    error = assert_raises(ArgumentError) do
      @tool.validate_and_call("nope")
    end

    assert_equal "Invalid arguments: expected an object", error.message
  end

  def test_validate_and_call_requires_required_properties
    error = assert_raises(ArgumentError) do
      @tool.validate_and_call({ "name" => "hello" })
    end

    assert_equal "Invalid arguments: missing required property 'count'", error.message
  end

  def test_validate_and_call_validates_string_type
    error = assert_raises(ArgumentError) do
      @tool.validate_and_call({
        "name" => 123,
        "count" => 1
      })
    end

    assert_equal "Invalid arguments: property 'name' must be a string", error.message
  end

  def test_validate_and_call_validates_integer_type
    error = assert_raises(ArgumentError) do
      @tool.validate_and_call({
        "name" => "hello",
        "count" => "1"
      })
    end

    assert_equal "Invalid arguments: property 'count' must be an integer", error.message
  end

  def test_validate_and_call_validates_boolean_type
    error = assert_raises(ArgumentError) do
      @tool.validate_and_call({
        "name" => "hello",
        "count" => 1,
        "enabled" => "true"
      })
    end

    assert_equal "Invalid arguments: property 'enabled' must be a boolean", error.message
  end

  def test_validate_and_call_validates_array_type
    error = assert_raises(ArgumentError) do
      @tool.validate_and_call({
        "name" => "hello",
        "count" => 1,
        "tags" => "nope"
      })
    end

    assert_equal "Invalid arguments: property 'tags' must be an array", error.message
  end

  def test_validate_and_call_validates_object_type
    error = assert_raises(ArgumentError) do
      @tool.validate_and_call({
        "name" => "hello",
        "count" => 1,
        "options" => "nope"
      })
    end

    assert_equal "Invalid arguments: property 'options' must be an object", error.message
  end

  def test_validate_and_call_rejects_object_defaults
    tool_class = Class.new(Tidewave::Tool) do
      def definition
        {
          "name" => "bad_default",
          "description" => "A bad default tool.",
          "inputSchema" => {
            "type" => "object",
            "properties" => {
              "options" => {
                "type" => "object",
                "default" => {}
              }
            }
          }
        }
      end

      def call(arguments)
        arguments
      end
    end

    tool = tool_class.new

    error = assert_raises(ArgumentError) do
      tool.validate_and_call({})
    end

    assert_equal "Invalid tool definition: property 'options' cannot use an object or array default", error.message
  ensure
    Tidewave::Tool.descendants.delete(tool_class)
  end
end
