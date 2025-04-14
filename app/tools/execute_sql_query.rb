# frozen_string_literal: true

class ExecuteSqlQuery < Tidewave::Tool
  tool_name "execute_sql_query"
  description <<~DESCRIPTION
    Executes the given SQL query against the ActiveRecord database connection.
    Returns the result as a Ruby data structure.

    Note that the output is limited to 50 rows at a time. If you need to see more, perform additional calls
    using LIMIT and OFFSET in the query. If you know that only specific columns are relevant,
    only include those in the SELECT clause.

    You can use this tool to select user data, manipulate entries, and introspect the application data domain.
    Always ensure to use the correct SQL commands for the database you are using.

    For PostgreSQL, use $1, $2, etc. for parameter placeholders.
    For MySQL, use ? for parameter placeholders.
  DESCRIPTION

  arguments do
    required(:query).filled(:string).description("The SQL query to execute. For PostgreSQL, use $1, $2 placeholders. For MySQL, use ? placeholders.")
    optional(:arguments).value(:array).description("The arguments to pass to the query. The query must contain corresponding parameter placeholders.")
  end

  RESULT_LIMIT = 50

  def call(query:, arguments: [])
    # Get the ActiveRecord connection
    conn = ActiveRecord::Base.connection

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
      database: Rails.configuration.database_configuration.dig(Rails.env, "database")
    }
  end
end
