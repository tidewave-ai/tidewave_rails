# frozen_string_literal: true

class GetSourceLocation < ApplicationTool
  class << self
    # The version of Ruby that this tool is compatible with is 3.4.0 and above.
    MAJOR_VERSION_THRESHOLD = 3
    MINOR_VERSION_THRESHOLD = 4

    COMPATIBLE_LABEL = "compatible".freeze
    INCOMPATIBLE_LABEL = "incompatible".freeze

    def ruby_version_compatible_label
      ruby_version_compatible? ? COMPATIBLE_LABEL : INCOMPATIBLE_LABEL
    end

    def ruby_version_compatible?
      major, minor, _patch = ruby_version.split(".").map(&:to_i)
      major > MAJOR_VERSION_THRESHOLD || (major == MAJOR_VERSION_THRESHOLD && minor >= MINOR_VERSION_THRESHOLD)
    end

    def ruby_version
      RUBY_VERSION
    end

    # We override the description method to prevent from being loa
    def description
      <<~DESCRIPTION
        Returns the source location for the given module (or function).

        This works for modules in the current project, as well as dependencies.

        This tool only works if you know the specific module (and optionally function) that is being targeted.
        If that is the case, prefer this tool over grepping the file system.

        ## Ruby version compatibility
        Due to a Ruby bug, this tool only works with Ruby >= 3.4.0.
        Your ruby version is #{ruby_version_compatible_label} with this tool.
      DESCRIPTION
    end
  end

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

  private

  def get_source_location(module_name, function_name)
    module_ref = module_name.constantize
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
