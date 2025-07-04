# frozen_string_literal: true

module Tidewave
  module DatabaseAdapters
    class Sequel < DatabaseAdapter
      RESULT_LIMIT = 50

      def execute_query(query, arguments = [])
        db = ::Sequel::Model.db

        # Execute the query with arguments
        result = if arguments.any?
          db.fetch(query, *arguments)
        else
          db.fetch(query)
        end

        # Convert to array of hashes and extract metadata
        rows = result.all
        columns = rows.first&.keys || []

        # Format the result similar to ActiveRecord
        {
          columns: columns.map(&:to_s),
          rows: rows.first(RESULT_LIMIT).map(&:values),
          row_count: rows.length,
          adapter: adapter_name,
          database: database_name
        }
      end

      def get_models
        # Ensure all models are loaded
        Rails.application.eager_load!

        models = ::Sequel::Model.descendants.map do |model|
          { name: model.name, relationships: get_relationships(model) }
        end

        models.to_json
      end

      def adapter_name
        ::Sequel::Model.db.adapter_scheme.to_s.upcase
      end

      def database_name
        db = ::Sequel::Model.db
        case db.adapter_scheme
        when :postgres, :postgresql
          db.opts[:database]
        when :mysql, :mysql2
          db.opts[:database]
        when :sqlite
          db.opts[:database]
        else
          db.opts[:database] || "unknown"
        end
      end

      private

      def get_relationships(model)
        associations = []

        # Get all associations defined on the model
        model.association_reflections.each do |name, reflection|
          associations << {
            name: name,
            type: reflection[:type]
          }
        end

        associations.compact_blank
      end
    end
  end
end
