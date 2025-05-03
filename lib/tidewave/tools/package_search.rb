# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

class Tidewave::Tools::PackageSearch < Tidewave::Tools::Base
  tool_name "package_search"
  description <<~DESCRIPTION
    Searches for packages on RubyGems.

    Use this tool if you need to find new packages to add to the project. Before using this tool,
    get an overview of the existing dependencies by using the `project_eval` tool and executing
    `Gem::Specification.map { |gem| [gem.name, gem.version] }`.

    The results are paginated, with 30 packages per page. Use the `page` parameter to fetch a specific page.
  DESCRIPTION

  arguments do
    required(:search).filled(:string).description("The search term")
    optional(:page).filled(:integer, gt?: 0).description("The page number to fetch. Must be greater than 0. Defaults to 1.")
  end

  def call(search:, page: 1)
    uri = URI("https://rubygems.org/api/v1/search.json")
    uri.query = URI.encode_www_form(query: search, page: page)

    response = Net::HTTP.get_response(uri)

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body).map do |package|
        { name: package["name"], version: package["version"], downloads: package["downloads"] }
      end
    else
      raise "RubyGems API request failed with status code: #{response.code}"
    end
  end
end
