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
        ::ActiveRecord::Base.descendants.map do |model|
          if location = get_relative_source_location(model.name)
            "* #{model.name} at #{location}"
          else
            "* #{model.name}"
          end
        end.join("\n")
      end

      def adapter_name
        ::ActiveRecord::Base.connection.adapter_name
      end

      def database_name
        Rails.configuration.database_configuration.dig(Rails.env, "database")
      end

      private

      def get_relative_source_location(model_name)
        source_location = Object.const_source_location(model_name)
        return nil if source_location.blank?

        file_path, line_number = source_location
        begin
          relative_path = Pathname.new(file_path).relative_path_from(Rails.root)
          "#{relative_path}:#{line_number}"
        rescue ArgumentError
          # If the path cannot be made relative, return the absolute path
          "#{file_path}:#{line_number}"
        end
      end
    end
  end
end
