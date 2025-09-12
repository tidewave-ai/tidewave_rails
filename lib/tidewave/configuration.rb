# frozen_string_literal: true

module Tidewave
  class Configuration
    attr_accessor :logger, :allow_remote_access, :preferred_orm, :dev, :client_url, :team

    def initialize
      @logger = nil
      @allow_remote_access = true
      @preferred_orm = :active_record
      @dev = false
      @client_url = "https://tidewave.ai"
      @team = {}
    end
  end
end
