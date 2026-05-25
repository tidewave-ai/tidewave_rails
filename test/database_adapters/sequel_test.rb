# frozen_string_literal: true

require "test_helper"
require "tidewave/database_adapters/sequel"

class TidewaveDatabaseAdaptersSequelTest < TidewaveSequelTestCase
  def setup
    super
    @db = Sequel::Model.db
    @adapter = Tidewave::DatabaseAdapters::Sequel.new
    @users_table = :sequel_users
    @posts_table = :sequel_posts

    @db.create_table?(@users_table) do
      primary_key :id
      String :name
    end

    @db.create_table?(@posts_table) do
      primary_key :id
      String :title
      String :content
    end

    @db[@users_table].delete
    @db[@posts_table].delete

    @db[@users_table].insert(id: 1, name: "test")
    @db[@users_table].insert(id: 2, name: "user2")

    60.times do |index|
      @db[@posts_table].insert(id: index + 1, title: "Post #{index + 1}", content: "Content #{index + 1}")
    end
  end

  def test_execute_query_formats_results_without_arguments
    response = @adapter.execute_query("SELECT 1 as id, 'test' as name")

    assert_equal [ "id", "name" ], response[:columns]
    assert_equal [ [ 1, "test" ] ], response[:rows]
    assert_equal 1, response[:row_count]
    assert_equal "SQLITE", response[:adapter]
    assert_nil response[:database]
  end

  def test_execute_query_passes_arguments
    response = @adapter.execute_query("SELECT ? as id, ? as name", [ 42, "dynamic" ])

    assert_equal [ "id", "name" ], response[:columns]
    assert_equal [ [ 42, "dynamic" ] ], response[:rows]
    assert_equal 1, response[:row_count]
  end

  def test_execute_query_limits_rows_to_fifty
    response = @adapter.execute_query("SELECT * FROM #{@posts_table} ORDER BY id")

    assert_equal 60, response[:row_count]
    assert_equal 50, response[:rows].length
    assert_equal [ "id", "title", "content" ], response[:columns]
    assert_equal [ 1, "Post 1", "Content 1" ], response[:rows].first
    assert_equal [ 50, "Post 50", "Content 50" ], response[:rows].last
  end

  def test_execute_query_reraises_database_errors
    assert_raises(Sequel::DatabaseError) do
      @adapter.execute_query("SELECT * FROM nonexistent_table")
    end
  end

  def test_execute_query_handles_empty_results
    response = @adapter.execute_query("SELECT * FROM #{@users_table} WHERE id = -1")

    assert_equal [], response[:columns]
    assert_equal [], response[:rows]
    assert_equal 0, response[:row_count]
    assert_equal "SQLITE", response[:adapter]
    assert_nil response[:database]
  end

  def test_get_models_filters_anonymous_models
    base_model = Sequel::Model(@users_table)
    named_model = Class.new(base_model)
    Object.const_set(:TidewaveSequelNamedModel, named_model)
    filtered_model = Class.new(base_model) do
      def self.name
        "Sequel::_Model(#{@users_table.inspect})"
      end
    end

    models = @adapter.get_models

    assert_includes models, named_model
    refute_includes models, filtered_model
  ensure
    Object.send(:remove_const, :TidewaveSequelNamedModel) if Object.const_defined?(:TidewaveSequelNamedModel)
  end

  def test_get_models_keeps_nil_names
    base_model = Sequel::Model(@users_table)
    unnamed_model = Class.new(base_model)

    models = @adapter.get_models

    assert_includes models, unnamed_model
  end
end
