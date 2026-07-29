# frozen_string_literal: true

class Tidewave
  class Configuration
    attr_accessor :logger, :allow_remote_access, :cable, :preferred_orm, :dev, :client_url, :team, :logger_middleware, :toolbar

    def initialize
      # Rails has a hosts middleware which already checks for this
      @allow_remote_access = true
      # Cable adapter configuration for the browser control WebSocket.
      # Defaults to the app's config/cable.yml (or the in-process "async"
      # adapter when there is none).
      @cable = nil
      @logger = nil
      @preferred_orm = :active_record
      @dev = false
      @client_url = "https://tidewave.ai"
      @team = {}
      @logger_middleware = nil
      @toolbar = true
    end
  end
end
