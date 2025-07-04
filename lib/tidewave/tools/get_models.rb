# frozen_string_literal: true

class Tidewave::Tools::GetModels < Tidewave::Tools::Base
  tool_name "get_models"
  description <<~DESCRIPTION
    Returns a list of all models in the application and their relationships.
  DESCRIPTION

  def call
    Tidewave::DatabaseAdapter.current.get_models
  end
end
