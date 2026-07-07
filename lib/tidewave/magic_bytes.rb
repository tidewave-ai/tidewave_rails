# frozen_string_literal: true

class Tidewave
  module MagicBytes
    module_function

    def type(bytes)
      case bytes
      when /\A\xFF\xD8\xFF/n
        :jpg
      when /\A\x89PNG\r\n\x1A\n/n
        :png
      when /\A\x1A\x45\xDF\xA3/n
        bytes.include?("webm") ? :webm : :unknown
      else
        :unknown
      end
    end
  end
end
