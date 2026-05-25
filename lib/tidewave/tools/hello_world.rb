# frozen_string_literal: true

class Tidewave::Tools::HelloWorld < Tidewave::Tool
  def definition
    {
      "name" => "hello_world",
      "description" => "Returns a hello world greeting.",
      "inputSchema" => {
        "type" => "object",
        "properties" => {}
      }
    }
  end

  def call(_arguments = {})
    {
      "content" => [
        {
          "type" => "text",
          "text" => "Hello, world!"
        }
      ]
    }
  end
end
