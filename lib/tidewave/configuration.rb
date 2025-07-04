# frozen_string_literal: true

module Tidewave
  class Configuration
    attr_accessor :logger, :allowed_origins, :localhost_only, :allowed_ips, :preferred_orm

    def initialize
      @logger = nil
      @allowed_origins = nil
      @localhost_only = true
      @allowed_ips = nil
      @preferred_orm = nil # Can be :active_record, :sequel, or nil for auto-detection
    end
  end
end
