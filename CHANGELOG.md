# CHANGELOG

## v0.4.1 (2025-11-25)

* Fix compatibility with hash fields in Dry schema

## v0.4.0 (2025-10-17)

* Use Streamable HTTP transport
* Allow logger middleware to be customizable
* Use FastMCP ~> 1.6.0

## v0.3.1 (2025-09-16)

* Optimize `get_logs`
* Fix `get_models` tool to filter Sequel anonymous models
* Remove unused credentials support

## v0.3.0 (2025-09-08)

* Add `grep` option to `get_logs`
* Bundle `get_package_location` into `get_source_location`
* Support team configuration
* Remove deprecated file system tools

## v0.2.0 (2025-08-12)

* Support Tidewave Web
* Add Sequel ORM support
* Return Ruby inspection instead of JSON in tools
* Add `get_docs`
* Use a separate log file for Tidewave
* Remove `package_search` as it was rarely used as its output is limited to avoid injections

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