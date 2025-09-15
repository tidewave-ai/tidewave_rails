# frozen_string_literal: true

class Tidewave::Tools::GetModels < Tidewave::Tools::Base
  tool_name "get_models"
  description <<~DESCRIPTION
    Returns a list of all database-backed models in the application.
  DESCRIPTION

  def call
    # Ensure all models are loaded
    Rails.application.eager_load!

    # Use adapter to get models (encapsulates ORM-specific logic)
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

  def get_relative_source_location(model_name)
    source_location = Object.const_source_location(model_name)
    return nil if source_location.blank?

    file_path, line_number = source_location
    begin
      relative_path = Pathname.new(file_path).relative_path_from(Rails.root)
      "#{relative_path}:#{line_number}"
    rescue ArgumentError
      # If the path cannot be made relative, return the absolute path
      "#{file_path}:#{line_number}"
    end
  end
end
