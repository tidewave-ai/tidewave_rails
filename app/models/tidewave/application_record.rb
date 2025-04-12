# frozen_string_literal: true

module Tidewave
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
