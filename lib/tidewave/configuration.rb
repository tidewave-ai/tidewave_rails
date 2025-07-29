# frozen_string_literal: true

module Tidewave
  class Configuration
    attr_accessor :logger, :allow_remote_access, :preferred_orm

    def initialize
      @logger = nil
      @allow_remote_access = true
      @preferred_orm = :active_record
    end
  end
end
