# frozen_string_literal: true

Dir[File.expand_path("**/*_test.rb", __dir__)].sort.each do |file|
  next if file == __FILE__

  require file
end
