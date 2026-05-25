# frozen_string_literal: true

require "test_helper"
require "tidewave/quiet_requests_middleware"

class TidewaveQuietRequestsMiddlewareTest < Minitest::Test
  def setup
    @downstream_app = ->(_env) { [ 200, { "Content-Type" => "text/plain" }, [ "ok" ] ] }
    @middleware = Tidewave::QuietRequestsMiddleware.new(@downstream_app)
  end

  def test_tidewave_requests_are_silenced
    logger = Object.new
    called = false
    logger.define_singleton_method(:silence) do |&block|
      called = true
      block.call
    end
    Rails.logger = logger

    status, _headers, body = perform_request("/tidewave/config")

    assert_equal 200, status
    assert_equal "ok", body
    assert_equal true, called
  end

  def test_non_tidewave_requests_skip_silencing
    logger = Object.new
    logger.define_singleton_method(:silence) do |&block|
      flunk "silence should not be called for non-tidewave routes"
    end
    Rails.logger = logger

    status, _headers, body = perform_request("/other-route")

    assert_equal 200, status
    assert_equal "ok", body
  end

  private

  def perform_request(path)
    status, headers, response = @middleware.call(Rack::MockRequest.env_for(path))
    body = +""
    response.each { |part| body << part }
    response.close if response.respond_to?(:close)
    [ status, headers, body ]
  end
end
