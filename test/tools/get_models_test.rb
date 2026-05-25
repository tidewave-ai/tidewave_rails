# frozen_string_literal: true

require "pathname"
require "test_helper"

class TidewaveGetModelsUser < ActiveRecord::Base
end

class TidewaveGetModelsPost < ActiveRecord::Base
end

class TidewaveGetModelsComment < ActiveRecord::Base
end

class TidewaveGetModelsTest < TidewaveActiveRecordTestCase
  def setup
    super
    connection = ActiveRecord::Base.connection
    @users_table = "get_models_users"
    @posts_table = "get_models_posts"
    @comments_table = "get_models_comments"

    TidewaveGetModelsUser.table_name = @users_table
    TidewaveGetModelsPost.table_name = @posts_table
    TidewaveGetModelsComment.table_name = @comments_table
    TidewaveGetModelsUser.reset_column_information
    TidewaveGetModelsPost.reset_column_information
    TidewaveGetModelsComment.reset_column_information

    connection.create_table(@users_table) { |table| table.string :name } unless connection.table_exists?(@users_table)
    connection.create_table(@posts_table) { |table| table.string :title } unless connection.table_exists?(@posts_table)
    connection.create_table(@comments_table) { |table| table.string :body } unless connection.table_exists?(@comments_table)
  end

  def test_validate_and_call_returns_models_with_source_locations
    eager_loaded = false
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

  def test_validate_and_call_handles_models_without_source_location
    missing_source_model = Class.new(ActiveRecord::Base) do
      def self.name
        "TidewaveMissingSourceModel"
      end
    end
    missing_source_model.table_name = @users_table
    missing_source_model.reset_column_information

    tool = Tidewave::Tools::GetModels.new(
      root: Pathname.pwd,
      orm_adapter: :active_record
    )

    result = tool.validate_and_call({})

    assert_includes result, "* TidewaveGetModelsUser at test/tools/get_models_test.rb:"
    assert_includes result, "* TidewaveMissingSourceModel"
  end

  def test_definition_is_nil_when_orm_adapter_is_missing
    tool = Tidewave::Tools::GetModels.new(root: Pathname.pwd)

    assert_nil tool.definition
  end

  def test_definition_uses_a_valid_empty_object_input_schema
    tool = Tidewave::Tools::GetModels.new(
      root: Pathname.pwd,
      orm_adapter: :active_record
    )

    assert_equal(
      {
        "type" => "object",
        "properties" => {}
      },
      tool.definition.fetch("inputSchema")
    )
  end
end
