# frozen_string_literal: true

require_relative "lib/tidewave/version"

Gem::Specification.new do |spec|
  spec.name        = "tidewave"
  spec.version     = Tidewave::VERSION
  spec.authors     = [ "Yorick Jacquin" ]
  spec.email       = [ "yorickjacquin@gmail.com" ]
  spec.homepage    = "https://github.com/tidewave-ai/tidewave_rails"
  spec.summary     = "Rails MCP server"
  spec.description = "Rails MCP server"
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/tidewave-ai/tidewave_rails"
  spec.metadata["changelog_uri"] = "https://github.com/tidewave-ai/tidewave_rails/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 7.2.0"
  spec.add_dependency "fast-mcp", "~> 1.1.0"
  spec.add_dependency "faraday", "~> 2.13.0"
end
