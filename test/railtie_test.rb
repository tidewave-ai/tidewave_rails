# frozen_string_literal: true

require "test_helper"

class TidewaveRailtieTest < Minitest::Test
  def test_railtie_boots_and_inserts_middleware_with_expected_options
    app = TidewaveRailtieTestApp::Application
    middleware = app.middleware
    classes = middleware.map(&:klass)

    assert_equal Tidewave::QuietRequestsMiddleware, classes[classes.index(ActionDispatch::ShowExceptions) - 1]
    assert_equal Tidewave::ExceptionsMiddleware, classes[classes.index(ActionDispatch::DebugExceptions) - 1]
    assert_equal Tidewave, classes[classes.index(ActionDispatch::Callbacks) + 1]

    tidewave_entry = middleware.find { |entry| entry.klass == Tidewave }
    options = tidewave_entry.args.first

    assert_equal false, options[:allow_remote_access]
    assert_equal [ "localhost" ], options[:allowed_origins]
    assert_equal "https://example.test", options[:client_url]
    assert_equal "rails", options[:framework_type]
    assert_equal "TidewaveRailtieTestApp", options[:project_name]
    assert_equal({ id: "dashbit" }, options[:team])
    assert_same TidewaveRailtieTestApp::LOGGER, options[:logger]
    assert_equal TidewaveRailtieTestApp::ROOT, options[:root]
    assert_equal TidewaveRailtieTestApp::ROOT.join("log", "#{Rails.env}.log"), options[:log_file]
    assert_equal :sequel, options[:orm_adapter]
    assert options.key?(:tmp_dir)
    assert_nil options[:tmp_dir]
    assert_kind_of Proc, options[:before_reload]
  end
end
