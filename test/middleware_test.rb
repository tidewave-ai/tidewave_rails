# frozen_string_literal: true

require "logger"
require "stringio"
require "test_helper"
require "tidewave/configuration"
require "tidewave/middleware"

class TidewaveMiddlewareTest < Minitest::Test
  def setup
    app_class = Class.new
    app_class.define_singleton_method(:module_parent) { Struct.new(:name).new("MiddlewareTestApp") }
    Rails.application = app_class.new
    Rails.logger = Logger.new(StringIO.new)
  end

  def test_non_tidewave_routes_strip_x_frame_options
    downstream = ->(_env) { [ 200, { "Content-Type" => "text/plain", "X-Frame-Options" => "DENY" }, [ "Downstream App" ] ] }
    middleware = Tidewave::Middleware.new(downstream, Tidewave::Configuration.new)

    status, headers, body = perform_request(middleware, "/other-route")

    assert_equal 200, status
    assert_equal "Downstream App", body
    assert_nil headers["X-Frame-Options"]
  end

  def test_config_endpoint_uses_rails_specific_defaults
    config = Tidewave::Configuration.new
    config.team = { id: "dashbit" }
    config.allow_remote_access = true
    middleware = Tidewave::Middleware.new(->(_env) { [ 200, {}, [ "ignored" ] ] }, config)

    status, headers, body = perform_request(middleware, "/tidewave/config")

    assert_equal 200, status
    assert_equal "application/json", headers["Content-Type"]

    payload = JSON.parse(body)
    assert_equal "rails", payload["framework_type"]
    assert_equal "MiddlewareTestApp", payload["project_name"]
    assert_equal({ "id" => "dashbit" }, payload["team"])
  end

  private

  def perform_request(app, path)
    status, headers, response = app.call(Rack::MockRequest.env_for(path))
    body = +""
    response.each { |part| body << part }
    response.close if response.respond_to?(:close)
    [ status, headers, body ]
  end
end
