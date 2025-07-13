# frozen_string_literal: true

class Tidewave::Tools::GetModels < Tidewave::Tools::Base
  tool_name "get_models"
  description <<~DESCRIPTION
    Returns a list of all models in the application and their relationships.
  DESCRIPTION

  def call
    # Ensure all models are loaded
    Rails.application.eager_load!

    ActiveRecord::Base.descendants.map do |model|
      {
        name: model.name,
        relationships: get_relationships(model),
        source_location: get_relative_source_location(model.name)
      }
    end
  end

  private

  def get_relative_source_location(model_name)
    source_location = Object.const_source_location(model_name)
    return nil if source_location.blank?

    file_path, line_number = source_location
    relative_path = Pathname.new(file_path).relative_path_from(Rails.root)
    "#{relative_path}:#{line_number}"
  rescue ArgumentError
    # If the path cannot be made relative, return the absolute path
    "#{file_path}:#{line_number}"
  end

  def get_relationships(model)
    model.reflect_on_all_associations.map do |association|
      { name: association.name, type: association.macro }
    end.compact_blank
  end
end
