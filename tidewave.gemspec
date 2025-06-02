# frozen_string_literal: true

require_relative "lib/tidewave/version"

Gem::Specification.new do |spec|
  spec.name        = "tidewave"
  spec.version     = Tidewave::VERSION
  spec.authors     = [ "Yorick Jacquin" ]
  spec.email       = [ "support@tidewave.ai" ]
  spec.homepage    = "https://tidewave.ai/"
  spec.summary     = "Tidewave for Rails"
  spec.description = "Tidewave for Rails"
  spec.license     = "Apache-2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/tidewave-ai/tidewave_rails"
  spec.metadata["changelog_uri"] = "https://github.com/tidewave-ai/tidewave_rails/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "LICENSE", "README.md"]
  end

  spec.add_dependency "rails", ">= 7.1.0"
  spec.add_dependency "fast-mcp", ">= 1.4", "< 1.6"
  spec.add_dependency "rack", ">= 2.0"
end
