# frozen_string_literal: true

require "action_dispatch"
require "active_support/core_ext/string/inflections"
require "test_helper"
require "tidewave/exceptions_middleware"

class TidewaveExceptionsMiddlewareTest < Minitest::Test
  def setup
    Rails.backtrace_cleaner = Object.new
    Rails.logger = Object.new
    Rails.logger.define_singleton_method(:error) { |_message| nil }
  end

  def test_call_appends_exception_information
    exception = RuntimeError.new("Test error message")
    exception.set_backtrace([
      "/app/controllers/test_controller.rb:10:in `show'",
      "/app/lib/some_lib.rb:20:in `process'"
    ])

    app = lambda do |env|
      request = ActionDispatch::Request.new(env)
      request.set_header("tidewave.exception", exception)
      [ 200, { "Content-Type" => "text/html" }, [ "<html><body><h1>Error Page</h1></body></html>" ] ]
    end

    Rails.backtrace_cleaner.define_singleton_method(:clean) { |_backtrace| exception.backtrace }

    status, _headers, body = perform_request(
      Tidewave::ExceptionsMiddleware.new(app),
      path_parameters: { "controller" => "test", "action" => "show" }
    )

    assert_equal 200, status
    assert_includes body, "data-tidewave-exception-info"
    assert_includes body, "RuntimeError in TestController#show"
    assert_includes body, "Test error message"
    assert_includes body, "/app/controllers/test_controller.rb:10:in `show&#39;"
  end

  def test_call_handles_exceptions_without_controller_parameters
    exception = RuntimeError.new("Test error message")
    exception.set_backtrace([])

    app = lambda do |env|
      ActionDispatch::Request.new(env).set_header("tidewave.exception", exception)
      [ 200, { "Content-Type" => "text/html" }, [ "<html><body><h1>Error Page</h1></body></html>" ] ]
    end

    Rails.backtrace_cleaner.define_singleton_method(:clean) { |_backtrace| [] }

    status, _headers, body = perform_request(Tidewave::ExceptionsMiddleware.new(app))

    assert_equal 200, status
    assert_includes body, "RuntimeError"
    refute_includes body, "Controller"
    refute_includes body, "## Backtrace"
  end

  def test_call_leaves_response_untouched_when_no_exception_is_present
    app = ->(_env) { [ 200, { "Content-Type" => "text/html" }, [ "<html><body><h1>Hello World</h1></body></html>" ] ] }

    status, _headers, body = perform_request(Tidewave::ExceptionsMiddleware.new(app))

    assert_equal 200, status
    assert_equal "<html><body><h1>Hello World</h1></body></html>", body
    refute_includes body, "data-tidewave-exception-info"
  end

  private

  def perform_request(app, path_parameters: nil)
    env = Rack::MockRequest.env_for("/")
    env["action_dispatch.request.path_parameters"] = path_parameters if path_parameters

    status, headers, response = app.call(env)
    body = +""
    response.each { |part| body << part }
    response.close if response.respond_to?(:close)
    [ status, headers, body ]
  end
end
