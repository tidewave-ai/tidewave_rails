# Tidewave

Tidewave is the coding agent for full-stack web app development, deeply integrated with Rails, from the database to the UI. [See our website](https://tidewave.ai) for more information.

This project can also be used as a standalone Model Context Protocol server for your editors.

## Installation

You can install Tidewave by adding the `tidewave` gem to the development group in your Gemfile:

```ruby
gem "tidewave", group: :development
```

Now access `/tidewave` route of your web application to enjoy Tidewave Web!

## Troubleshooting

### Localhost requirement

Tidewave expects your web application to be running on `localhost`. If you are not running on localhost, you may need to set some additional configuration. In particular, you must configure Tidewave to allow `allow_remote_access` and [optionally configure your Rails hosts](https://guides.rubyonrails.org/configuring.html#actiondispatch-hostauthorization). For example, in your `config/environments/development.rb`:

```ruby
config.hosts << "company.local"
config.tidewave.allow_remote_access = true
```

If you want to use Docker for development, you either need to enable the configuration above or automatically redirect the relevant ports, as done by [devcontainers](https://code.visualstudio.com/docs/devcontainers/containers). See our [containers](https://hexdocs.pm/tidewave/containers.html) guide for more information.

### Content security policy

If you have enabled Content-Security-Policy, Tidewave will automatically enable "unsafe-eval" under `script-src` in order for contextual browser testing to work correctly. It also disables the `frame-ancestors` directive.

### Production Environment

Tidewave is a powerful tool that can help you develop your web application faster and more efficiently. However, it is important to note that Tidewave is not meant to be used in a production environment.

Tidewave will raise an error if it is used in any environment where code reloading is disabled (which typically includes production).

## Configuration

You may configure `tidewave` using the following syntax:

```ruby
  config.tidewave.allow_remote_access = true
```

The following config is available:

  * `allow_remote_access` - Tidewave only allows requests from localhost by default, even if your server listens on other interfaces as well. If you trust your network and need to access Tidewave from a different machine, this configuration can be set to `true`

  * `logger_middleware` - The logger middleware Tidewave should wrap to silence its own logs

  * `preferred_orm` - which ORM to use, either `:active_record` (default) or `:sequel`

  * `team` - set your Tidewave Team configuration, such as `config.tidewave.team = { id: "my-company" }`

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
