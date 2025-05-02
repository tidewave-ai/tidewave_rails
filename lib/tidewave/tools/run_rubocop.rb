# frozen_string_literal: true

require "open3"
require "bundler"

class Tidewave::Tools::RunRubocop < Tidewave::Tools::Base
  class RubocopNotInstalledError < StandardError; end
  class CommandFailedError < StandardError; end

  tool_name "run_rubocop"
  description <<~DESCRIPTION
    Runs RuboCop static code analyzer with the specified options.
    This tool will only work if the RuboCop gem is included in the project's Gemfile.

    RuboCop is a Ruby static code analyzer and formatter that enforces many of the
    guidelines outlined in the community Ruby Style Guide.

    Returns the output of the RuboCop command if successful, or raises an error if RuboCop
    is not installed or if the command fails.
  DESCRIPTION

  arguments do
    optional(:path).filled(:string).description("The file or directory path to run RuboCop on. Defaults to the entire project.")
    optional(:options).maybe(:string).description("Additional RuboCop options (e.g., '--auto-correct', '--format=json').")
  end

  def call(path: nil, options: nil)
    verify_rubocop_installed
    command = build_command(path, options)
    stdout, status = Open3.capture2e(command)

    unless status.exitstatus.between?(0, 1)  # RuboCop returns 1 when it finds offenses
      raise CommandFailedError, "RuboCop command failed with status #{status.exitstatus}:\n\n#{stdout}"
    end

    stdout.strip
  end

  private

  def verify_rubocop_installed
    unless rubocop_installed?
      raise RubocopNotInstalledError, "RuboCop gem is not installed in this project. Add it to your Gemfile to use this tool."
    end
  end

  def rubocop_installed?
    return @rubocop_installed unless @rubocop_installed.nil?

    @rubocop_installed = begin
      spec = Bundler.load.specs.find { |s| s.name == "rubocop" }
      !spec.nil?
    rescue Bundler::GemfileNotFound, Bundler::GemNotFound, Bundler::BundlerError
      false
    end
  end

  def build_command(path, options)
    cmd_parts = [ "bundle exec rubocop" ]
    cmd_parts << "--no-color" # Ensures clean output without ANSI color codes
    cmd_parts << options if options
    cmd_parts << path if path

    cmd_parts.join(" ")
  end
end
