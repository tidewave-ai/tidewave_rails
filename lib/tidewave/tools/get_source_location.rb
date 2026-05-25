# frozen_string_literal: true

require "pathname"

class Tidewave::Tools::GetSourceLocation < Tidewave::Tool
  DESCRIPTION = <<~DESCRIPTION.freeze
    Returns the source location for the given reference.

    The reference may be a constant, most commonly classes and modules
    such as `String`, an instance method, such as `String#gsub`, or class
    method, such as `File.executable?`

    This tool only works if you know the specific constant/method being targeted,
    and it works across the current project and all dependencies.
    If that is the case, prefer this tool over grepping the file system.

    You may also get the root location of a gem, you can use "dep:PACKAGE_NAME".
  DESCRIPTION

  def definition
    {
      "name" => "get_source_location",
      "description" => DESCRIPTION,
      "inputSchema" => {
        "type" => "object",
        "properties" => {
          "reference" => {
            "type" => "string",
            "description" => "The constant/method to lookup, such String, String#gsub or File.executable?",
            "minLength" => 1
          }
        },
        "required" => [ "reference" ]
      }
    }
  end

  def call(arguments)
    reference = arguments.fetch("reference")

    if reference.start_with?("dep:")
      get_package_location(reference.delete_prefix("dep:"))
    else
      file_path, line_number = self.class.get_source_location(reference)
      raise NameError, "could not find source location for #{reference}" unless file_path

      format_source_location(file_path, line_number)
    end
  end

  def self.get_source_location(reference)
    constant_path, selector, method_name = reference.rpartition(/\.|#/)
    return Object.const_source_location(method_name) if selector.empty?

    begin
      mod = Object.const_get(constant_path)
    rescue NameError => error
      raise error
    rescue StandardError
      raise "wrong or invalid reference #{reference}"
    end

    raise "reference #{constant_path} does not point a class/module" unless mod.is_a?(Module)

    if selector == "#"
      mod.instance_method(method_name).source_location
    else
      mod.method(method_name).source_location
    end
  end

  private

  def format_source_location(file_path, line_number)
    relative_path = Pathname.new(file_path).relative_path_from(project_root)
    "#{relative_path}:#{line_number}"
  rescue ArgumentError
    "#{file_path}:#{line_number}"
  end

  def project_root
    if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
      Pathname.new(Rails.root.to_s)
    else
      Pathname.pwd
    end
  end

  def get_package_location(package)
    raise "dep: prefix only works with projects using Bundler" unless defined?(Bundler)

    spec = Bundler.load.specs.find { |loaded_spec| loaded_spec.name == package }
    return spec.full_gem_path if spec

    raise "Package #{package} not found. Check your Gemfile for available packages."
  end
end
