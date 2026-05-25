# frozen_string_literal: true

require "sequel"
require "test_helper"
require "tidewave/database_adapters/sequel"

class TidewaveDatabaseAdaptersSequelTest < Minitest::Test
  def setup
    @original_db = Sequel::Model.db
    @had_original_db = true
  rescue Sequel::Error
    @original_db = nil
    @had_original_db = false
  ensure
    @db = Sequel.sqlite
    Sequel::Model.db = @db
    @adapter = Tidewave::DatabaseAdapters::Sequel.new

    @db.create_table(:users) do
      primary_key :id
      String :name
    end

    @db.create_table(:posts) do
      primary_key :id
      String :title
      String :content
    end

    @db[:users].insert(id: 1, name: "test")
    @db[:users].insert(id: 2, name: "user2")

    60.times do |index|
      @db[:posts].insert(id: index + 1, title: "Post #{index + 1}", content: "Content #{index + 1}")
    end
  end

  def teardown
    Sequel::Model.db = @original_db if @had_original_db
    @db.disconnect
  end

  def test_execute_query_formats_results_without_arguments
    response = with_database do
      @adapter.execute_query("SELECT 1 as id, 'test' as name")
    end

    assert_equal [ "id", "name" ], response[:columns]
    assert_equal [ [ 1, "test" ] ], response[:rows]
    assert_equal 1, response[:row_count]
    assert_equal "SQLITE", response[:adapter]
    assert_nil response[:database]
  end

  def test_execute_query_passes_arguments
    response = with_database do
      @adapter.execute_query("SELECT ? as id, ? as name", [ 42, "dynamic" ])
    end

    assert_equal [ "id", "name" ], response[:columns]
    assert_equal [ [ 42, "dynamic" ] ], response[:rows]
    assert_equal 1, response[:row_count]
  end

  def test_execute_query_limits_rows_to_fifty
    response = with_database do
      @adapter.execute_query("SELECT * FROM posts ORDER BY id")
    end

    assert_equal 60, response[:row_count]
    assert_equal 50, response[:rows].length
    assert_equal [ "id", "title", "content" ], response[:columns]
    assert_equal [ 1, "Post 1", "Content 1" ], response[:rows].first
    assert_equal [ 50, "Post 50", "Content 50" ], response[:rows].last
  end

  def test_execute_query_reraises_database_errors
    assert_raises(Sequel::DatabaseError) do
      with_database do
        @adapter.execute_query("SELECT * FROM nonexistent_table")
      end
    end
  end

  def test_execute_query_handles_empty_results
    response = with_database do
      @adapter.execute_query("SELECT * FROM users WHERE id = -1")
    end

    assert_equal [], response[:columns]
    assert_equal [], response[:rows]
    assert_equal 0, response[:row_count]
    assert_equal "SQLITE", response[:adapter]
    assert_nil response[:database]
  end

  def test_get_models_filters_anonymous_models
    account = Struct.new(:name).new("Account")
    user = Struct.new(:name).new("User")
    anonymous = Struct.new(:name).new("Sequel::_Model(:users)")

    models = with_descendants([ account, user, anonymous ]) do
      @adapter.get_models
    end

    assert_equal [ account, user ], models
  end

  def test_get_models_keeps_nil_names
    named = Struct.new(:name).new("Account")
    nil_name = Struct.new(:name).new(nil)

    models = with_descendants([ named, nil_name ]) do
      @adapter.get_models
    end

    assert_equal [ named, nil_name ], models
  end

  private

  def with_database(&block)
    block.call
  end

  def with_descendants(descendants)
    singleton = Sequel::Model.singleton_class
    had_original = Sequel::Model.respond_to?(:descendants)
    original_method = Sequel::Model.method(:descendants) if had_original

    singleton.define_method(:descendants) { descendants }
    yield
  ensure
    singleton.remove_method(:descendants)
    singleton.define_method(:descendants, original_method) if had_original
  end
end
