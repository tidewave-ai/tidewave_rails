# frozen_string_literal: true

module Tidewave
  class Configuration
    attr_accessor :logger, :allowed_origins, :localhost_only, :allowed_ips, :preferred_orm

    def initialize
      @logger = nil
      @allowed_origins = nil
      @localhost_only = true
      @allowed_ips = nil
      @preferred_orm = :active_record # Default to :active_record, can be :sequel
    end
  end
end
