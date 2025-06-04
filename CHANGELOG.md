# CHANGELOG

## v0.1.3

* Merge `glob_project_files` tool into `list_project_files`
* Add `get_package_location` tool
* Add `line_offset` and `count` parameters to `read_project_file` tool
* Add Ruby syntax validation before writing `.rb` files
* Rename `get_source_location` parameter to "reference", which expects either `String.new` or `String#gsub`
* Add download counts to package information

## v0.1.2

* Also support Rails 7.1
* Load class core extension before using it
* Allow configuration from Rails

## v0.1.1

* Bump to fast-mcp 1.3.1
* Do not attempt to missing generator fixtures
* Drop `Faraday` in favor of `Net::HTTP` for RubyGems API calls

## v0.1.0

* Initial release