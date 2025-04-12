# frozen_string_literal: true

# Tidewave MCP - Model Context Protocol Integration
# This initializer configures the integration between your Rails application
# and Tidewave's Model Context Protocol server.

require "fast_mcp"

# The Tidewave gem provides:
# 1. Automatic integration with the Model Context Protocol through the fast-mcpgem
# 2. A collection of precoded AI tools ready to use with your application
# 3. Automatic discovery of your custom tools in app/tools
#
# All tools (both precoded and custom) will be automatically registered
# with the MCP server and made available to AI clients.

# To customize the MCP endpoint paths:
#  Modify these options in the same call:
#  path_prefix: "/custom/path",
#  messages_route: "messages",
#  sse_route: "sse"
#
# For more details, see the FastMcp documentation: https://github.com/yjacquin/fast-mcp

# You can add your own initialization code here if needed
