# frozen_string_literal: true

require "faraday"

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
    response = rubygems_client.get("/api/v1/search.json?query=#{search}&page=#{page}")

    response.body
  end

  private

  def rubygems_client
    @rubygems_client ||= Faraday.new(url: "https://rubygems.org") do |faraday|
      faraday.response :raise_error

      faraday.adapter Faraday.default_adapter
    end
  end
end
