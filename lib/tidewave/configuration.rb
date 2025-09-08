# frozen_string_literal: true

module Tidewave
  class Configuration
    attr_accessor :logger, :allow_remote_access, :preferred_orm, :credentials, :client_url, :team

    def initialize
      @logger = nil
      @allow_remote_access = true
      @preferred_orm = :active_record
      @credentials = {}
      @client_url = "https://tidewave.ai"
      @team = {}
    end
  end
end
