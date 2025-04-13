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

Then, access the inspector's UI, choose SSE protocol, and for the URL, enter: `http://localhost:3001/tidewave/sse`

_I am aware we want to use `/tidewave/mcp`, I just need to publish the new gem version for this feature, it will be done soon._

## Cursor tests
I have encountered errors while trying it out with Cursor, I will debug this ASAP.