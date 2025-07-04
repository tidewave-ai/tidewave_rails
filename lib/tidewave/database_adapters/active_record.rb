# frozen_string_literal: true

module Tidewave
  module DatabaseAdapters
    class ActiveRecord < DatabaseAdapter
      RESULT_LIMIT = 50

      def execute_query(query, arguments = [])
        conn = ::ActiveRecord::Base.connection

        # Execute the query with prepared statement and arguments
        if arguments.any?
          result = conn.exec_query(query, "SQL", arguments)
        else
          result = conn.exec_query(query)
        end

        # Format the result
        {
          columns: result.columns,
          rows: result.rows.first(RESULT_LIMIT),
          row_count: result.rows.length,
          adapter: conn.adapter_name,
          database: database_name
        }
      end

      def get_models
        # Ensure all models are loaded
        Rails.application.eager_load!

        models = ::ActiveRecord::Base.descendants.map do |model|
          { name: model.name, relationships: get_relationships(model) }
        end

        models.to_json
      end

      def adapter_name
        ::ActiveRecord::Base.connection.adapter_name
      end

      def database_name
        Rails.configuration.database_configuration.dig(Rails.env, "database")
      end

      private

      def get_relationships(model)
        model.reflect_on_all_associations.map do |association|
          { name: association.name, type: association.macro }
        end.compact_blank
      end
    end
  end
end
