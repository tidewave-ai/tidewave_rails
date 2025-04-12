# frozen_string_literal: true

require "rails/generators/base"

module Tidewave
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs Tidewave MCP server into your Rails application"

      def check_fast_mcp_installed
        unless defined?(FastMcp)
          say "Fast MCP gem is required. Please run 'bundle add fast-mcp' first.", :red
          exit
        end
      end

      def create_initializer
        template "tidewave_initializer.rb", "config/initializers/tidewave.rb"
      end

      def display_post_install_message
        say "\n==========================================================="
        say "Tidewave MCP was successfully installed! \u{1F30A}"
        say "===========================================================\n"
        say "Tidewave's precoded tools and your application's tools"
        say "in app/tools/ will be automatically discovered and"
        say "registered with the MCP server."
        say "\n"
        say "Check config/initializers/tidewave.rb for configuration options."
        say "===========================================================\n"
      end
    end
  end
end
