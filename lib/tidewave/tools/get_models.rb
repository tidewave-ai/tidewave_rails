# frozen_string_literal: true

require "pathname"

class Tidewave::Tools::GetModels < Tidewave::Tool
  DESCRIPTION = <<~DESCRIPTION.freeze
    Returns a list of all database-backed models in the application.
  DESCRIPTION

  def initialize(options = {})
    @root = options[:root] ? Pathname.new(options[:root].to_s) : Pathname.pwd
    @database_adapter = Tidewave::DatabaseAdapter.for(options[:orm_adapter]) if options[:orm_adapter]
    @before_reload = options[:before_reload]
  end

  def definition
    return nil unless @database_adapter

    {
      "name" => "get_models",
      "description" => DESCRIPTION,
      "inputSchema" => {
        "type" => "object",
        "properties" => {}
      }
    }
  end

  def call(_arguments)
    @before_reload&.call

    models = @database_adapter.get_models

    models.map do |model|
      if location = get_relative_source_location(model.name)
        "* #{model.name} at #{location}"
      else
        "* #{model.name}"
      end
    end.join("\n")
  end

  private

  def get_relative_source_location(model_name)
    source_location = Object.const_source_location(model_name)
    return nil unless source_location

    file_path, line_number = source_location
    relative_path = Pathname.new(file_path).relative_path_from(@root)
    "#{relative_path}:#{line_number}"
  rescue ArgumentError
    "#{file_path}:#{line_number}"
  end
end
