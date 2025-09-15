# frozen_string_literal: true

class Tidewave::Tools::GetLogs < Tidewave::Tools::Base
  tool_name "get_logs"
  description <<~DESCRIPTION
    Returns all log output, excluding logs that were caused by other tool calls.

    Use this tool to check for request logs or potentially logged errors.
  DESCRIPTION

  arguments do
    required(:tail).filled(:integer).description("The number of log entries to return from the end of the log")
    optional(:grep).filled(:string).description("Filter logs with the given regular expression (case insensitive). E.g. \"error\" when you want to capture errors in particular")
  end

  def call(tail:, grep: nil)
    log_file = Rails.root.join("log", "#{Rails.env}.log")
    return "Log file not found" unless File.exist?(log_file)

    regex = Regexp.new(grep, Regexp::IGNORECASE) if grep
    matching_lines = []

    File.foreach(log_file) do |line|
      matching_lines << line if regex.nil? or line.match?(regex)
      matching_lines.shift if matching_lines.size > tail
    end

    matching_lines.last(tail).join
  end
end
