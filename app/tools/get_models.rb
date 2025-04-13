# frozen_string_literal: true

class GetModels < ApplicationTool
  tool_name "get_models"
  description <<~DESCRIPTION
    Returns a list of all models in the application and their relationships.
  DESCRIPTION

  arguments do
    optional(:association_type).filled(:string, included_in?: %w[has_many has_one belongs_to]).description(
      "The type of association to include in the response. Can be 'has_many', 'has_one' or 'belongs_to'. If omitted, all association types will be included."
    )
  end

  def call(association_type: nil)
    association_type_as_symbol = association_type&.to_sym

    # Ensure all models are loaded
    Rails.application.eager_load!

    models = ActiveRecord::Base.descendants.map do |model|
      { name: model.name, relationships: get_relationships(model, association_type_as_symbol) }
    end

    models.to_json
  end

  private

  def get_relationships(model, association_type)
    model.reflect_on_all_associations(association_type).map do |association|
      { name: association.name, type: association.macro }
    end.compact_blank
  end
end
