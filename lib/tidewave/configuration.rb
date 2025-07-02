# frozen_string_literal: true

module Tidewave
  class Configuration
    attr_accessor :logger, :allowed_origins, :localhost_only, :allowed_ips

    def initialize(log_file)
      @logger = Logger.new(log_file)
      @allowed_origins = nil
      @localhost_only = true
      @allowed_ips = nil
    end
  end
end
