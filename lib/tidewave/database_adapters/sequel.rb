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
        ::Sequel::Model.descendants.map do |model|
          if location = get_relative_source_location(model.name)
            "* #{model.name} at #{location}"
          else
            "* #{model.name}"
          end
        end.join("\n")
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
