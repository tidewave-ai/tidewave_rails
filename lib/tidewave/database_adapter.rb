# frozen_string_literal: true

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
  end
end
