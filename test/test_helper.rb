# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "json"
require "logger"
require "minitest/autorun"
require "minitest/pride"
require "pathname"
require "rack/mock_request"
require "stringio"
require "action_controller/railtie"
require "active_record"
require "sequel"
require "tidewave"

module TidewaveRailtieTestApp
  ROOT = Pathname.new(File.expand_path("..", __dir__))
  LOGGER = ActiveSupport::Logger.new(StringIO.new)

  class Application < Rails::Application
    config.root = ROOT
    config.eager_load = false
    config.enable_reloading = true
    config.secret_key_base = "x" * 30
    config.hosts.clear
    config.logger = LOGGER
    config.tidewave.allow_remote_access = false
    config.tidewave.client_url = "https://example.test"
    config.tidewave.team = { id: "dashbit" }
    config.tidewave.preferred_orm = :sequel
    config.tidewave.logger = LOGGER
    config.tidewave.logger_middleware = ActionDispatch::ShowExceptions
    config.content_security_policy do |policy|
      policy.default_src :self
      policy.frame_ancestors :self
      policy.script_src_elem :self
      policy.connect_src :none
    end
  end
end

TidewaveRailtieTestApp::Application.initialize! unless TidewaveRailtieTestApp::Application.initialized?
Rails.backtrace_cleaner.remove_silencers!
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
Sequel::Model.db = Sequel.sqlite

class TidewaveActiveRecordTestCase < Minitest::Test
end

class TidewaveSequelTestCase < Minitest::Test
end
