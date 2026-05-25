# frozen_string_literal: true

class Tidewave::Tools::GetDocs < Tidewave::Tool
  DESCRIPTION = <<~DESCRIPTION.freeze
    Returns the documentation for the given reference.

    The reference may be a constant, most commonly classes and modules
    such as `String`, an instance method, such as `String#gsub`, or class
    method, such as `File.executable?`

    This works for methods in the current project, as well as dependencies.

    This tool only works if you know the specific constant/method being targeted.
    If that is the case, prefer this tool over grepping the file system.
  DESCRIPTION

  def definition
    {
      "name" => "get_docs",
      "description" => DESCRIPTION,
      "inputSchema" => {
        "type" => "object",
        "properties" => {
          "reference" => {
            "type" => "string",
            "minLength" => 1,
            "description" => "The constant/method to lookup, such String, String#gsub or File.executable?"
          }
        },
        "required" => [ "reference" ]
      }
    }
  end

  def call(arguments)
    reference = arguments.fetch("reference")
    file_path, line_number = Tidewave::Tools::GetSourceLocation.get_source_location(reference)

    if file_path
      extract_documentation(file_path, line_number)
    else
      raise NameError, "could not find docs for #{reference}"
    end
  end

  private

  def extract_documentation(file_path, line_number)
    return nil unless File.exist?(file_path)

    lines = File.readlines(file_path)
    return nil if line_number <= 0 || line_number > lines.length

    # Start from the line before the method definition
    current_line = line_number - 2 # Convert to 0-based index and go one line up
    comment_lines = []

    # Collect comment lines going backwards
    while current_line >= 0
      line = lines[current_line].chomp.strip

      if line.start_with?("#")
        comment = line.sub(/^#\s|^#/, "")
        comment_lines.unshift(comment) unless ignorable_comment?(comment)
      elsif line.empty?
        # Skip empty lines but continue looking for comments
      else
        # Hit a non-comment, non-empty line, stop collecting
        break
      end

      current_line -= 1
    end

    return nil if comment_lines.empty?
    comment_lines.join("\n")
  end

  def ignorable_comment?(comment)
    comment.start_with?("rubocop:")
  end
end
