# frozen_string_literal: true

require "active_support/core_ext/string/inflections"
require "active_support/core_ext/object/blank"

class Tidewave::Tools::GetSourceLocation < Tidewave::Tools::Base
  tool_name "get_source_location"

  description <<~DESCRIPTION
    Returns the source location for the given reference.

    It may be a class/module, such as `String`, an instance method,
    such as `String#gsub`, or class method, such as `File.executable?`

    This works for methods in the current project, as well as dependencies.

    This tool only works if you know the specific method that is being targeted.
    If that is the case, prefer this tool over grepping the file system.
  DESCRIPTION

  arguments do
    required(:reference).filled(:string).description("The class/module/method to lookup, such String, String#gsub or File.executable?")
  end

  def call(reference:)
    file_path, line_number = get_source_location(reference)

    if file_path
    {
      file_path: file_path,
      line_number: line_number
    }.to_json
    else
      raise NameError, "Could not find source location for #{reference}"
    end
  end

  private

  def get_source_location(reference)
    constant_name, selector, method_name = reference.rpartition(/\.|#/)

    # This is a class/module lookup
    return Object.const_source_location(method_name) if selector.empty?

    constant = constant_name.constantize

    if selector == "#"
      begin
        constant.instance_method(method_name).source_location
      rescue
        raise NameError, "Could not find instance method #{method_name} on #{constant_name}"
      end
    else
      begin
        constant.method(method_name).source_location
      rescue
        raise NameError, "Could not find class method #{method_name} on #{constant_name}"
      end
    end
  end
end
