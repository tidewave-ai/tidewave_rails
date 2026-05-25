# frozen_string_literal: true

require "active_support/logger"
require "logger"
require "stringio"
require "test_helper"
require "tidewave/quiet_requests_middleware"

class TidewaveQuietRequestsMiddlewareTest < Minitest::Test
  def test_tidewave_requests_are_silenced
    io = StringIO.new
    logger = ActiveSupport::Logger.new(io)
    logger.level = Logger::DEBUG

    status, _headers, body = with_rails_logger(logger) do
      perform_request(Tidewave::QuietRequestsMiddleware.new(logging_app), "/tidewave/config")
    end

    assert_equal 200, status
    assert_equal "ok", body
    refute_includes io.string, "request log"
  end

  def test_non_tidewave_requests_skip_silencing
    io = StringIO.new
    logger = ActiveSupport::Logger.new(io)
    logger.level = Logger::DEBUG

    status, _headers, body = with_rails_logger(logger) do
      perform_request(Tidewave::QuietRequestsMiddleware.new(logging_app), "/other-route")
    end

    assert_equal 200, status
    assert_equal "ok", body
    assert_includes io.string, "request log"
  end

  private

  def logging_app
    lambda do |_env|
      Rails.logger.info("request log")
      [ 200, { "Content-Type" => "text/plain" }, [ "ok" ] ]
    end
  end

  def perform_request(app, path)
    status, headers, response = app.call(Rack::MockRequest.env_for(path))
    body = +""
    response.each { |part| body << part }
    response.close if response.respond_to?(:close)
    [ status, headers, body ]
  end

  def with_rails_logger(logger)
    original_logger = Rails.logger
    Rails.logger = logger
    yield
  ensure
    Rails.logger = original_logger
  end
end
