# frozen_string_literal: true

module Tidewave
  module Tools
    class Base < FastMcp::Tool
      def self.file_system_tool
        @file_system_tool = true
      end

      def self.file_system_tool?
        @file_system_tool
      end
    end
  end
end
