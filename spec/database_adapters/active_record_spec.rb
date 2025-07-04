# frozen_string_literal: true

require "rails_helper"
require "tidewave/database_adapters/active_record"

describe Tidewave::DatabaseAdapters::ActiveRecord do
  let(:adapter) { described_class.new }

  describe "#execute_query" do
    let(:connection) { instance_double("ActiveRecord::ConnectionAdapters::PostgreSQLAdapter") }
    let(:result) { instance_double("ActiveRecord::Result") }
    let(:row_count) { 60 }
    let(:rows) { row_count.times.map { |i| [ i, "Test #{i}" ] } }

    before do
      allow(::ActiveRecord::Base).to receive(:connection).and_return(connection)
      allow(connection).to receive(:adapter_name).and_return("PostgreSQL")
      allow(Rails).to receive_message_chain(:configuration, :database_configuration).and_return({
        "test" => {
          "database" => ":memory:"
        }
      })
      allow(result).to receive(:columns).and_return([ "id", "name" ])
      allow(result).to receive(:rows).and_return(rows)
    end

    context "with a simple query without arguments" do
      let(:query) { "SELECT * FROM users" }

      it "returns the first 50 rows of the query" do
        expect(connection).to receive(:exec_query).with(query).and_return(result)

        response = adapter.execute_query(query)

        expect(response).to eq({
          columns: [ "id", "name" ],
          rows: rows.first(50),
          row_count: row_count,
          adapter: "PostgreSQL",
          database: ":memory:"
        })
      end

      context 'with a row_count smaller than the result limit' do
        let(:row_count) { 10 }
        let(:rows) { row_count.times.map { |i| [ i, "Test #{i}" ] } }

        it "returns all rows" do
          expect(connection).to receive(:exec_query).with(query).and_return(result)

          response = adapter.execute_query(query)

          expect(response).to eq({
            columns: [ "id", "name" ],
            rows: rows,
            row_count: row_count,
            adapter: "PostgreSQL",
            database: ":memory:"
          })
        end
      end
    end

    context "with query arguments" do
      let(:query) { "SELECT * FROM users WHERE id = $1" }
      let(:arguments) { [ 1 ] }

      it "passes the arguments to the exec_query method" do
        expect(connection).to receive(:exec_query).with(query, "SQL", arguments).and_return(result)

        adapter.execute_query(query, arguments)
      end
    end
  end

  describe "#get_models" do
    let(:user_model) { double("User", name: "User") }
    let(:post_model) { double("Post", name: "Post") }
    let(:comment_model) { double("Comment", name: "Comment") }

    let(:models) { [ user_model, post_model, comment_model ] }

    let(:has_many_association) { double("has_many_association", name: :posts, macro: :has_many) }
    let(:belongs_to_association) { double("belongs_to_association", name: :user, macro: :belongs_to) }
    let(:has_one_association) { double("has_one_association", name: :profile, macro: :has_one) }

    before do
      # Mock Rails.application.eager_load!
      allow(Rails.application).to receive(:eager_load!)

      # Mock ActiveRecord::Base.descendants
      allow(::ActiveRecord::Base).to receive(:descendants).and_return(models)

      # Set up the relationships for each model
      allow(user_model).to receive(:reflect_on_all_associations).and_return([ has_many_association, has_one_association ])

      allow(post_model).to receive(:reflect_on_all_associations).and_return([ belongs_to_association ])

      allow(comment_model).to receive(:reflect_on_all_associations).and_return([])
    end

    it "returns all models with all their relationships" do
      expected_response = [
        {
          name: "User",
          relationships: [
            { name: :posts, type: :has_many },
            { name: :profile, type: :has_one }
          ]
        },
        {
          name: "Post",
          relationships: [
            { name: :user, type: :belongs_to }
          ]
        },
        {
          name: "Comment",
          relationships: []
        }
      ].to_json

      expect(adapter.get_models).to eq(expected_response)
    end
  end

  describe "#adapter_name" do
    it "returns the ActiveRecord adapter name" do
      connection = instance_double("ActiveRecord::ConnectionAdapters::PostgreSQLAdapter")
      allow(::ActiveRecord::Base).to receive(:connection).and_return(connection)
      allow(connection).to receive(:adapter_name).and_return("PostgreSQL")

      expect(adapter.adapter_name).to eq("PostgreSQL")
    end
  end

  describe "#database_name" do
    it "returns the database name from Rails configuration" do
      allow(Rails).to receive_message_chain(:configuration, :database_configuration).and_return({
        "test" => {
          "database" => "test_database"
        }
      })

      expect(adapter.database_name).to eq("test_database")
    end
  end
end
