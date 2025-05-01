module Tidewave
  class Configuration
    attr_accessor :logger, :allowed_origins, :localhost_only, :allowed_ips

    def initialize
      @logger = Logger.new(STDOUT)
      @allowed_origins = nil
      @localhost_only = true
      @allowed_ips = nil
    end
  end
end
