# frozen_string_literal: true

require "pathname"

class Tidewave::Tools::GetLogs < Tidewave::Tool
  DESCRIPTION = <<~DESCRIPTION.freeze
    Returns all log output, excluding logs that were caused by other tool calls.

    Use this tool to check for request logs or potentially logged errors.
  DESCRIPTION

  def initialize(options = {})
    @log_file = options[:log_file] ? Pathname.new(options[:log_file].to_s) : nil
  end

  def definition
    return nil unless @log_file

    {
      "name" => "get_logs",
      "description" => DESCRIPTION,
      "inputSchema" => {
        "type" => "object",
        "properties" => {
          "tail" => {
            "type" => "integer",
            "not" => {
              "type" => "null"
            },
            "description" => "The number of log entries to return from the end of the log"
          },
          "grep" => {
            "type" => "string",
            "minLength" => 1,
            "description" => "Filter logs with the given regular expression (case insensitive). E.g. \"error\" when you want to capture errors in particular"
          }
        },
        "required" => [ "tail" ]
      }
    }
  end

  def call(arguments)
    tail = arguments.fetch("tail")
    grep = arguments["grep"]
    return "Log file not found" unless @log_file&.exist?

    regex = Regexp.new(grep, Regexp::IGNORECASE) if grep
    matching_lines = []

    tail_lines(@log_file) do |line|
      if regex.nil? || line.match?(regex)
        matching_lines.unshift(line)
        break if matching_lines.size >= tail
      end
    end

    matching_lines.join
  end

  private

  def tail_lines(file_path)
    File.open(file_path, "rb") do |file|
      file.seek(0, IO::SEEK_END)
      file_size = file.pos
      return if file_size == 0

      buffer_size = [ 4096, file_size ].min
      pos = file_size
      buffer = ""

      while pos > 0 && buffer.count("\n") < 10000 # Safety limit
        # Move back by buffer_size or to beginning of file
        seek_pos = [ pos - buffer_size, 0 ].max
        file.seek(seek_pos)

        # Read chunk
        chunk = file.read(pos - seek_pos)
        buffer = chunk + buffer
        pos = seek_pos

        # Extract complete lines from buffer
        lines = buffer.split("\n")

        # Keep the first partial line (if any) for next iteration
        if pos > 0 && !buffer.start_with?("\n")
          buffer = lines.shift || ""
        else
          buffer = ""
        end

        # Yield lines in reverse order (last to first)
        lines.reverse_each do |line|
          yield line + "\n" unless line.empty?
        end

        break if pos == 0
      end

      # Handle any remaining buffer content
      unless buffer.empty?
        yield buffer + "\n"
      end
    end
  end
end
