# frozen_string_literal: true

require "logger"
require "tidewave/configuration"
require "tidewave/exceptions_middleware"
require "tidewave/quiet_requests_middleware"

class Tidewave
  class Railtie < Rails::Railtie
    config.tidewave = Tidewave::Configuration.new()

    initializer "tidewave.setup" do |app|
      unless app.config.enable_reloading
        raise "For security reasons, Tidewave is only supported in environments where config.enable_reloading is true (typically development)"
      end

      tidewave_config = app.config.tidewave

      app.config.middleware.insert_after(
        ActionDispatch::Callbacks,
        Tidewave,
        allow_remote_access: tidewave_config.allow_remote_access,
        allowed_origins: tidewave_config.allowed_origins || Tidewave::Railtie.default_allowed_origins(app),
        client_url: tidewave_config.client_url,
        framework_type: "rails",
        project_name: app.class.module_parent.name,
        team: tidewave_config.team,
        logger: tidewave_config.logger || Rails.logger,
        root: Rails.root,
        log_file: Rails.root.join("log", "#{Rails.env}.log"),
        orm_adapter: tidewave_config.preferred_orm,
        tmp_dir: tidewave_config.tmp_dir,
        before_reload: -> { app.eager_load! }
      )

      app.config.after_initialize do
        # If the user configured CSP, we need to alter it in dev
        # to allow TC to run browser_eval.
        app.config.content_security_policy.try do |content_security_policy|
          content_security_policy.directives["script-src"].try do |script_src|
            script_src << "'unsafe-eval'" unless script_src.include?("'unsafe-eval'")
          end

          content_security_policy.directives.delete("frame-ancestors")
        end
      end
    end

    initializer "tidewave.intercept_exceptions" do |app|
      # We intercept exceptions from DebugExceptions, format the
      # information as text and inject into the exception page html.
      ActionDispatch::DebugExceptions.register_interceptor do |request, exception|
        request.set_header("tidewave.exception", exception)
      end

      app.middleware.insert_before(ActionDispatch::DebugExceptions, Tidewave::ExceptionsMiddleware)
    end

    initializer "tidewave.logging" do |app|
      # Do not pollute user logs with tidewave requests.
      logger_middleware = app.config.tidewave.logger_middleware || Rails::Rack::Logger
      app.middleware.insert_before(logger_middleware, Tidewave::QuietRequestsMiddleware)
    end

    def self.default_allowed_origins(app)
      host = app.routes.default_url_options[:host]
      host ? [ host ] : Tidewave::DEFAULT_ALLOWED_ORIGINS
    end
  end
end
