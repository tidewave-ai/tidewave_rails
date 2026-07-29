# frozen_string_literal: true

require "logger"
require "uri"
require "tidewave/browser_control"
require "tidewave/configuration"
require "tidewave/exceptions_middleware"
require "tidewave/quiet_requests_middleware"

class Tidewave
  class Railtie < Rails::Railtie
    config.tidewave = Tidewave::Configuration.new()

    def self.cable_config(app)
      return nil unless app.root.join("config", "cable.yml").exist?

      app.config_for(:cable)&.to_h&.deep_stringify_keys
    rescue StandardError => error
      Rails.logger&.warn("Tidewave could not load config/cable.yml: #{error.message}")
      nil
    end

    initializer "tidewave.setup" do |app|
      unless app.config.enable_reloading
        raise "For security reasons, Tidewave is only supported in environments where config.enable_reloading is true (typically development)"
      end

      tidewave_config = app.config.tidewave

      app.config.middleware.insert_after(
        ActionDispatch::Callbacks,
        Tidewave,
        allow_remote_access: tidewave_config.allow_remote_access,
        browser_control: Tidewave::BrowserControl.new(cable: tidewave_config.cable || Railtie.cable_config(app)),
        client_url: tidewave_config.client_url,
        framework_type: "rails",
        project_name: app.class.module_parent.name,
        team: tidewave_config.team,
        toolbar: tidewave_config.toolbar,
        logger: tidewave_config.logger || Rails.logger,
        root: Rails.root,
        log_file: Rails.root.join("log", "#{Rails.env}.log"),
        orm_adapter: tidewave_config.preferred_orm,
        before_reload: -> { app.eager_load! }
      )

      app.config.after_initialize do
        # If the user configured CSP, we need to alter it in dev
        # to allow TC to run browser_eval.
        app.config.content_security_policy.try do |content_security_policy|
          directives = content_security_policy.directives
          script_src = directives["script-src"] || directives["default-src"]&.dup
          client_origin = URI.parse(tidewave_config.client_url.to_s).origin

          script_src.try do
            script_src << "'unsafe-eval'" unless script_src.include?("'unsafe-eval'")
            script_src << client_origin unless script_src.include?(client_origin)
            directives["script-src"] = script_src
          end

          directives["script-src-elem"].try do |script_src_elem|
            script_src_elem << client_origin unless script_src_elem.include?(client_origin)
          end

          directives.delete("frame-ancestors")
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
  end
end
