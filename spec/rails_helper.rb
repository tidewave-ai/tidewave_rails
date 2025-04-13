# frozen_string_literal: true

require 'rails/all'
require 'rspec/rails'

ENV['RAILS_ENV'] = 'test'

# Configure a minimal test application
class TestApplication < Rails::Application
  config.eager_load = false
end

# Initialize the Rails application
Rails.application.initialize!
