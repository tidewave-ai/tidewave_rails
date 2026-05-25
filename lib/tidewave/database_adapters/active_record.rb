# frozen_string_literal: true

class Tidewave
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
          database: conn.pool.db_config.database
        }
      end

      def get_models
        ::ActiveRecord::Base.descendants
      end
    end
  end
end
