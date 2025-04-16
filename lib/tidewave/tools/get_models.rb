# frozen_string_literal: true

class Tidewave::Tools::GetModels < Tidewave::Tools::Base
  tool_name "get_models"
  description <<~DESCRIPTION
    Returns a list of all models in the application and their relationships.
  DESCRIPTION

  def call
    # Ensure all models are loaded
    Rails.application.eager_load!

    models = ActiveRecord::Base.descendants.map do |model|
      { name: model.name, relationships: get_relationships(model) }
    end

    models.to_json
  end

  private

  def get_relationships(model)
    model.reflect_on_all_associations.map do |association|
      { name: association.name, type: association.macro }
    end.compact_blank
  end
end
