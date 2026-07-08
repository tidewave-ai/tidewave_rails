# frozen_string_literal: true

class Tidewave
  class Configuration
    attr_accessor :logger, :allow_remote_access, :allowed_origins, :preferred_orm, :dev, :client_url, :team,
      :logger_middleware, :tmp_dir

    def initialize
      # Rails has a hosts middleware which already checks for this
      @allow_remote_access = true
      @allowed_origins = nil
      @logger = nil
      @preferred_orm = :active_record
      @dev = false
      @client_url = "https://tidewave.ai"
      @team = {}
      @logger_middleware = nil
      @tmp_dir = nil
    end
  end
end
