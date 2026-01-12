# Tidewave

Tidewave is the coding agent for full-stack web app development. Integrate Claude Code, OpenAI Codex, and other agents with your web app and web framework at every layer, from UI to database. [See our website](https://tidewave.ai) for more information.

This project can also be used as [a standalone Model Context Protocol server](https://hexdocs.pm/tidewave/mcp.html).

## Installation

You can install Tidewave by running:

```shell
bundle add tidewave --group development
```

or by manully adding the `tidewave` gem to the development group in your Gemfile:

```ruby
gem "tidewave", group: :development
```

Now make sure [Tidewave is installed](https://hexdocs.pm/tidewave/installation.html) and you are ready to connect Tidewave to your app.

## Troubleshooting

### Using multiple hosts/subdomains

If you are using multiple hosts/subdomains during development, you must use `*.localhost`, as such domains are considered secure by browsers. Additionally, add the following to `config/initializers/development.rb`:

```ruby
config.session_store :cookie_store,
  key: "__your_app_session",
  same_site: :none,
  secure: true,
  assume_ssl: true
```

And make sure you are using `rack-session` version `2.1.0` or later.

The above will allow your application to run embedded within Tidewave across multiple subdomains, as long as it is using a secure context (such as `admin.localhost`, `www.foobar.localhost`, etc).

### Content security policy

If you have enabled Content-Security-Policy, Tidewave will automatically enable "unsafe-eval" under `script-src` in order for contextual browser testing to work correctly. It also disables the `frame-ancestors` directive.

### Production Environment

Tidewave is a powerful tool that can help you develop your web application faster and more efficiently. However, it is important to note that Tidewave is not meant to be used in a production environment.

Tidewave will raise an error if it is used in any environment where code reloading is disabled (which typically includes production).

## Configuration

You may configure `tidewave` using the following syntax:

```ruby
  config.tidewave.team = { id: "my-company" }
```

The following config is available:

  * `allow_remote_access` - Tidewave only allows requests from localhost by default, even if your server listens on other interfaces. If you trust your network and need to access Tidewave from a different machine, this configuration can be set to `true`

  * `logger_middleware` - The logger middleware Tidewave should wrap to silence its own logs

  * `preferred_orm` - which ORM to use, either `:active_record` (default) or `:sequel`

  * `team` - set your Tidewave Team configuration, such as `config.tidewave.team = { id: "my-company" }`

## Available tools

- `execute_sql_query` - executes a SQL query within your application
  database, useful for the agent to verify the result of an action

- `get_docs` - get the documentation for a given module/class/method.
  It consults the exact versions used by the project, ensuring you always
  get correct information

- `get_logs` - reads logs written by the server

- `get_models` - lists all modules in the application and their location
  for quick discovery

- `get_source_location` - get the source location for a given module/class/method,
  so an agent can directly read the source skipping search

- `project_eval` - evaluates code within the Rails application itself, giving the agent
  access to your runtime, dependencies, and in-memory data

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
