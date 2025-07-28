# frozen_string_literal: true

module Tidewave
  class Configuration
    attr_accessor :logger, :allow_remote_access, :allowed_ips, :preferred_orm

    def initialize
      @logger = nil
      @allow_remote_access = true
      @allowed_ips = nil
      @preferred_orm = :active_record
    end
  end
end
