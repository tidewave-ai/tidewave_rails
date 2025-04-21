# frozen_string_literal: true

class Tidewave::Tools::Grep < Tidewave::Tools::Base
  def self.ripgrep_executable
    @ripgrep_executable ||= `which rg`.strip
  end

  def self.ripgrep_available?
    ripgrep_executable.present?
  end

  def self.description
    "Searches for text patterns in files using #{ripgrep_available? ? 'ripgrep' : 'a grep variant'}."
  end
  tool_name "grep"

  arguments do
    required(:pattern).filled(:string).description("The pattern to search for")
    optional(:glob).filled(:string).description(
      'Optional glob pattern to filter which files to search in, e.g., \"**/*.ex\". Note that if a glob pattern is used, the .gitignore file will be ignored.'
    )
    optional(:case_sensitive).filled(:bool).description("Whether the search should be case-sensitive. Defaults to false.")
    optional(:max_results).filled(:integer).description("Maximum number of results to return. Defaults to 100.")
  end

  def call(pattern:, glob: "**/*", case_sensitive: false, max_results: 100)
    if self.class.ripgrep_available?
      execute_ripgrep(pattern, glob, case_sensitive, max_results)
    else
      execute_grep(pattern, glob, case_sensitive, max_results)
    end
  end

  private

  def execute_ripgrep(pattern, glob, case_sensitive, max_results)
    command = [ self.class.ripgrep_executable ]
    command << "--no-require-git" # ignore gitignored files
    command << "--json" # formatted as json
    command << "--max-count=#{max_results}"
    command << "--ignore-case" unless case_sensitive
    command << "--glob=#{glob}" if glob.present?
    command << pattern
    command << "." # Search in current directory

    results = `#{command.join(" ")} 2>&1`

    # Process the results as needed
    format_ripgrep_results(results)
  end

  def execute_grep(pattern, glob, case_sensitive, max_results)
    files = Tidewave::Tools::Glob.new.call(pattern: glob)
    results = []
    files.each do |file|
      next unless File.file?(file)

      begin
        file_matches = 0
        line_number = 0

        File.foreach(file) do |line|
          line_number += 1

          # Check if line matches pattern with proper case sensitivity
          if case_sensitive
            next unless line.include?(pattern)
          else
            next unless line.downcase.include?(pattern.downcase)
          end

          results << {
            "path" => file,
            "line_number" => line_number,
            "content" => line.strip
          }

          file_matches += 1
          # Stop processing this file if we've reached max results for it
          break if file_matches >= max_results
        end
      rescue => e
        # Skip files that can't be read (e.g., binary files)
        next
      end
    end

    results.to_json
  end

  def format_ripgrep_results(results)
    parsed_results = results.split("\n").map(&:strip).reject(&:empty?).map do |line|
      JSON.parse(line)
    end

    parsed_results.map do |result|
      next if result["type"] != "match"

      {
        "path" => result.dig("data", "path", "text"),
        "line_number" => result.dig("data", "line_number"),
        "content" => result.dig("data", "lines", "text").strip
      }
    end.compact.to_json
  end
end
