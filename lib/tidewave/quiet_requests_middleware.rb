# frozen_string_literal: true

class Tidewave::QuietRequestsMiddleware < Rails::Rack::Logger
  def initialize(app)
    @app = app
  end

  def call(env)
    if env["PATH_INFO"].start_with?("/tidewave")
      Rails.logger.silence { @app.call(env) }
    else
      @app.call(env)
    end
  end
end
