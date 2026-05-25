# frozen_string_literal: true

require "pathname"

class Tidewave::Tools::GetModels < Tidewave::Tool
  DESCRIPTION = <<~DESCRIPTION.freeze
    Returns a list of all database-backed models in the application.
  DESCRIPTION

  def definition
    {
      "name" => "get_models",
      "description" => DESCRIPTION,
      "inputSchema" => nil
    }
  end

  def call(_arguments)
    eager_load_models

    models = Tidewave::DatabaseAdapter.current.get_models

    models.map do |model|
      if location = get_relative_source_location(model.name)
        "* #{model.name} at #{location}"
      else
        "* #{model.name}"
      end
    end.join("\n")
  end

  private

  def eager_load_models
    return unless defined?(Rails) && Rails.respond_to?(:application) && Rails.application

    Rails.application.eager_load!
  end

  def get_relative_source_location(model_name)
    source_location = Object.const_source_location(model_name)
    return nil unless source_location

    file_path, line_number = source_location
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
end
