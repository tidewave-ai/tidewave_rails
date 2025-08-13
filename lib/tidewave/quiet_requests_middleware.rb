# frozen_string_literal: true

class Tidewave::QuietRequestsMiddleware < Rails::Rack::Logger
  def initialize(app)
    super(app)
  end

  def call(env)
    if env["PATH_INFO"].start_with?("/tidewave")
      Rails.logger.silence { super(env) }
    else
      super(env)
    end
  end
end
