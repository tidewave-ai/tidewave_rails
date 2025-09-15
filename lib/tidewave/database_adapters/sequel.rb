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
          adapter: db.adapter_scheme.to_s.upcase,
          database: db.opts[:database]
        }
      end

      def get_base_class
        ::Sequel::Model
      end

      def get_models
        # Filter out anonymous Sequel models that can't be resolved as constants
        get_base_class.descendants.reject { |model| model.name&.start_with?("Sequel::_Model(") }
      end
    end
  end
end
