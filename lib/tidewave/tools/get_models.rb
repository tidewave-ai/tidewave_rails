# frozen_string_literal: true

class Tidewave::Tools::GetModels < Tidewave::Tools::Base
  tool_name "get_models"
  description <<~DESCRIPTION
    Returns a list of all models in the application.
  DESCRIPTION

  def call
    # Ensure all models are loaded
    Rails.application.eager_load!

    Tidewave::DatabaseAdapter.current.get_models
  end
end
