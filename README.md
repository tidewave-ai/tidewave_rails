# Tidewave

Tidewave speeds up development with an AI assistant that understands your web application,
how it runs, and what it delivers. Our current release connects your editor's
assistant to your web framework runtime via [MCP](https://modelcontextprotocol.io/).

[See our website](https://tidewave.ai) for more information.

## Key Features

Tidewave provides tools that allow your LLM of choice to:

- inspect your application logs to help debugging errors
- execute SQL queries and inspect your database
- evaluate custom Ruby code in the context of your project
- find Rubygems packages and source code locations

and more.

## Installation

You can install Tidewave by adding the `tidewave` gem to the development group in your Gemfile:

```ruby
gem "tidewave", group: :development
```

Tidewave will now run on the same port as your regular Rails application.
In particular, the MCP is located by default at http://localhost:3000/tidewave/mcp.
[You must configure your editor and AI assistants accordingly](https://hexdocs.pm/tidewave/mcp.html).

## Considerations

### Production Environment

Tidewave is a powerful tool that can help you develop your web application faster and more efficiently.
However, it is important to note that Tidewave is not meant to be used in a production environment.

Tidewave will raise an error if it is used in a production environment.

### Web server requirements

Tidewave currently requires a threaded web server like Puma.

## Acknowledgements

A thank you to Yorick Jacquin, for creating [FastMCP](https://github.com/yjacquin/fast_mcp) and implementing the initial version of this project.

## License

Copyright (c) 2025 Dashbit

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
