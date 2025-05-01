# frozen_string_literal: true

module Tidewave
  module Tools
    class Base < FastMcp::Tool
      @descendants = []

      def self.inherited(subclass)
        @descendants ||= []
        @descendants << subclass

        super
      end

      def self.descendants
        @descendants || []
      end

      def self.file_system_tool
        @file_system_tool = true
      end

      def self.file_system_tool?
        @file_system_tool
      end
    end
  end
end
