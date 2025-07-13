# frozen_string_literal: true

module Tidewave
  class DatabaseAdapter
    class << self
      def current
        @current ||= create_adapter
      end

      def create_adapter
        orm_type = detect_orm
        case orm_type
        when :active_record
          require_relative "database_adapters/active_record"
          DatabaseAdapters::ActiveRecord.new
        when :sequel
          require_relative "database_adapters/sequel"
          DatabaseAdapters::Sequel.new
        else
          raise "No supported ORM detected. Please ensure ActiveRecord or Sequel is available."
        end
      end

      private

      def detect_orm
        # Check for preferred ORM setting first
        if Rails.application.config.respond_to?(:tidewave)
          preferred = Rails.application.config.tidewave.preferred_orm
          if preferred && [ :active_record, :sequel ].include?(preferred)
            return preferred if orm_available?(preferred)
          end
        end

        # Auto-detect based on what's defined
        if defined?(::ActiveRecord::Base)
          :active_record
        elsif defined?(::Sequel::Model)
          :sequel
        else
          # Try to require them to see if they're available
          begin
            require "active_record"
            :active_record
          rescue LoadError
            begin
              require "sequel"
              :sequel
            rescue LoadError
              nil
            end
          end
        end
      end

      def orm_available?(orm)
        case orm
        when :active_record
          !!defined?(::ActiveRecord::Base) || (require("active_record") rescue false)
        when :sequel
          !!defined?(::Sequel::Model) || (require("sequel") rescue false)
        else
          false
        end
      end
    end

    def execute_query(query, arguments = [])
      raise NotImplementedError, "Subclasses must implement execute_query"
    end

    def get_models
      raise NotImplementedError, "Subclasses must implement get_models"
    end

    def adapter_name
      raise NotImplementedError, "Subclasses must implement adapter_name"
    end

    def database_name
      raise NotImplementedError, "Subclasses must implement database_name"
    end
  end
end
