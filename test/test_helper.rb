# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "json"
require "minitest/autorun"
require "rack/mock_request"
require "tidewave"

module Rails
  class << self
    attr_accessor :application, :backtrace_cleaner, :configuration, :env, :logger, :root
  end
end unless defined?(Rails)
