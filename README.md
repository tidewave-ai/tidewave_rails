# Tidewave 🌊

## Installation
- Clone this repo to the desired path
- Add the gem to your Gemfile by referencing the path:
`gem 'tidewave', path: '/path/to/the/cloned/repo'`

## Usage
I have tested it againt the official MCP inspector ATM:
`npx @modelcontextprotocol/inspector`

Launch your rails server on port other than 3000 (as MCP inspector's proxy runs on 3000):
`bundle exec rails s -p 3001`

Then, access the inspector's UI, choose SSE protocol, and for the URL, enter: `http://localhost:3001/tidewave/mcp`

## Cursor Settings
open ~/.cursor/mcp.json:
```json
{
  "mcpServers": {
    "tidewave": {
      "url": "http://localhost:3001/tidewave/mcp"
    }
  }
}
```

## Acknowledgements

A thank you to Yorick Jacquin, for creating [FastMCP](https://github.com/yjacquin/fast_mcp)
and implementing the initial version of this project.

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
