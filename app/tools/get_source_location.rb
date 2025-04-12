# frozen_string_literal: true

require "active_support/core_ext/string/inflections"
require "active_support/core_ext/object/blank"

class GetSourceLocation < ApplicationTool
  tool_name "get_source_location"


  arguments do
    required(:module_name).filled(:string).description("The module to get source location for. When this is the single argument passed, the entire module source is returned.")
    optional(:function_name).filled(:string).description("The function to get source location for. When used, a module must also be passed.")
  end


  def call(module_name:, function_name: nil)
    file_path, line_number = get_source_location(module_name, function_name)

    {
      file_path: file_path,
      line_number: line_number
    }.to_json
  end

  description <<~DESCRIPTION
    Returns the source location for the given module (or function).

    This works for modules in the current project, as well as dependencies.

    This tool only works if you know the specific module (and optionally function) that is being targeted.
    If that is the case, prefer this tool over grepping the file system.
  DESCRIPTION

  private

  def get_source_location(module_name, function_name)
    begin
      module_ref = module_name.constantize
    rescue NameError
      raise NameError, "Module #{module_name} not found"
    end

    return get_method_definition(module_ref, function_name) if function_name.present?

    module_ref.const_source_location(module_name)
  end

  def get_method_definition(module_ref, function_name)
    module_ref.method(function_name).source_location
  rescue NameError
    get_instance_method_definition(module_ref, function_name)
  end

  def get_instance_method_definition(module_ref, function_name)
    module_ref.instance_method(function_name).source_location
  rescue NameError
    raise NameError, "Method #{function_name} not found in module #{module_ref.name}"
  end
end
