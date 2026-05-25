# frozen_string_literal: true

class Tidewave::Middleware < Tidewave
  def initialize(app, config)
    super(app, {
      allow_remote_access: config.allow_remote_access,
      client_url: config.client_url,
      framework_type: "rails",
      project_name: Rails.application.class.module_parent.name,
      team: config.team,
      logger: config.logger || Rails.logger
    })
  end

  def call(env)
    status, headers, body = super
    # Remove X-Frame-Options headers for non-Tidewave routes to allow embedding.
    # CSP headers are configured in the CSP application environment.
    headers.delete("X-Frame-Options")
    [ status, headers, body ]
  end
end
