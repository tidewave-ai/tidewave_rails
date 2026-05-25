# frozen_string_literal: true

require "test_helper"

class TidewaveGetDocsTestModule # rubocop:disable Layout/LeadingCommentSpace
  # This is a documented method
  # It does something important
  def self.documented_method
    "documented"
  end

  # This method has documentation
  # with multiple lines
  # and preserves indentation
  def documented_instance_method
    "instance"
  end

  def undocumented_method
    "undocumented"
  end

  #This comment has no space after hash
  def no_space_comment_method
    "no_space"
  end

  # This method has docs

  # with empty lines in between
  def docs_with_empty_lines
    "empty_lines"
  end

  #This is a comment without space
  #Another comment
  def multiple_no_space_comments
    "multiple_no_space"
  end

  # Comment with space
  #Comment without space
  def mixed_comment_styles
    "mixed"
  end
end # rubocop:enable Layout/LeadingCommentSpace

class TidewaveGetDocsTest < Minitest::Test
  def setup
    @tool = Tidewave::Tools::GetDocs.new
  end

  def test_validate_and_call_returns_class_method_documentation
    result = @tool.validate_and_call({ "reference" => "TidewaveGetDocsTestModule.documented_method" })

    assert_equal "This is a documented method\nIt does something important", result
  end

  def test_validate_and_call_returns_instance_method_documentation
    result = @tool.validate_and_call({ "reference" => "TidewaveGetDocsTestModule#documented_instance_method" })

    assert_equal "This method has documentation\nwith multiple lines\nand preserves indentation", result
  end

  def test_validate_and_call_returns_nil_for_undocumented_method
    result = @tool.validate_and_call({ "reference" => "TidewaveGetDocsTestModule#undocumented_method" })

    assert_nil result
  end

  def test_validate_and_call_handles_comments_without_space
    result = @tool.validate_and_call({ "reference" => "TidewaveGetDocsTestModule#no_space_comment_method" })

    assert_equal "This comment has no space after hash", result
  end

  def test_validate_and_call_ignores_empty_lines_between_comments
    result = @tool.validate_and_call({ "reference" => "TidewaveGetDocsTestModule#docs_with_empty_lines" })

    assert_equal "This method has docs\nwith empty lines in between", result
  end

  def test_validate_and_call_handles_multiple_comments_without_space
    result = @tool.validate_and_call({ "reference" => "TidewaveGetDocsTestModule#multiple_no_space_comments" })

    assert_equal "This is a comment without space\nAnother comment", result
  end

  def test_validate_and_call_handles_mixed_comment_styles
    result = @tool.validate_and_call({ "reference" => "TidewaveGetDocsTestModule#mixed_comment_styles" })

    assert_equal "Comment with space\nComment without space", result
  end

  def test_validate_and_call_returns_nil_for_undocumented_module
    result = @tool.validate_and_call({ "reference" => "TidewaveGetDocsTestModule" })

    assert_nil result
  end

  def test_validate_and_call_raises_when_reference_is_not_found
    error = assert_raises(NameError) do
      @tool.validate_and_call({ "reference" => "NonExistentModule" })
    end

    assert_equal "could not find docs for NonExistentModule", error.message
  end

  def test_validate_and_call_raises_when_reference_is_invalid
    error = assert_raises(NameError) do
      @tool.validate_and_call({ "reference" => "1+2" })
    end

    assert_equal "wrong constant name 1+2", error.message
  end
end
