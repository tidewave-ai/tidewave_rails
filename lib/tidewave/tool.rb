# frozen_string_literal: true

class Tidewave
  class Tool
    class << self
      def descendants
        @descendants ||= []
      end

      def inherited(subclass)
        descendants << subclass
        super
      end
    end

    def definition
      raise NotImplementedError, "#{self.class} must implement #definition"
    end

    def call(_arguments = {})
      raise NotImplementedError, "#{self.class} must implement #call"
    end
  end
end
