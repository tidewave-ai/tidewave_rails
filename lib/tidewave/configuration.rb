# frozen_string_literal: true

class Tidewave
  class Configuration
    attr_accessor :logger, :allow_remote_access, :preferred_orm, :dev, :client_url, :team, :logger_middleware

    def initialize
      # Rails has a hosts middleware which already checks for this
      @allow_remote_access = true
      @logger = nil
      @preferred_orm = :active_record
      @dev = false
      @client_url = "https://tidewave.ai"
      @team = {}
      @logger_middleware = nil
    end
  end
end
