# frozen_string_literal: true

require "base64"

class Tidewave
  class DatabaseAdapter
    class << self
      def for(orm_type)
        case orm_type
        when :active_record
          require_relative "database_adapters/active_record"
          DatabaseAdapters::ActiveRecord.new
        when :sequel
          require_relative "database_adapters/sequel"
          DatabaseAdapters::Sequel.new
        else
          raise "Unknown preferred ORM: #{orm_type}"
        end
      end
    end

    def execute_query(query, arguments = [])
      raise NotImplementedError, "Subclasses must implement execute_query"
    end

    def get_models
      raise NotImplementedError, "Subclasses must implement get_models"
    end

    private

    def normalize_result_rows(rows)
      rows.map do |row|
        row.map do |value|
          next value unless value.is_a?(String)

          begin
            text = case value.encoding
            when Encoding::UTF_8
              value.valid_encoding? ? value : value.scrub
            when Encoding::ASCII_8BIT
              next "base64:#{Base64.strict_encode64(value)}"
            else
              value.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
            end

            text.start_with?("base64:") ? text.sub("base64:", "base64::") : text
          rescue Encoding::ConverterNotFoundError
            "base64:#{Base64.strict_encode64(value)}"
          end
        end
      end
    end
  end
end
