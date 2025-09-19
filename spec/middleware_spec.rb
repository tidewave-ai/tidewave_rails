# frozen_string_literal: true

require "rack/test"

RSpec.describe Tidewave::Middleware do
  include Rack::Test::Methods

  let(:downstream_app) { ->(env) { [ 200, {}, [ "Downstream App" ] ] } }
  let(:config) { Tidewave::Configuration.new }
  let(:middleware) { described_class.new(downstream_app, config) }

  def app
    middleware
  end

  describe "routing" do
    context "when accessing non-tidewave routes" do
      it "passes through to downstream app" do
        get "/other-route"
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq("Downstream App")
      end

      it "passes through root route" do
        get "/"
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq("Downstream App")
      end
    end
  end

  describe "header removal" do
    let(:downstream_app_with_headers) do
      ->(env) { [ 200, { "Content-Security-Policy" => "default-src 'self'", "X-Frame-Options" => "DENY" }, [ "App with headers" ] ] }
    end
    let(:middleware_with_headers) { described_class.new(downstream_app_with_headers, config) }

    def app
      middleware_with_headers
    end

    it "removes CSP and X-Frame-Options headers from all responses" do
      get "/some-route"
      expect(last_response.status).to eq(200)
      expect(last_response.headers["Content-Security-Policy"]).to be_nil
      expect(last_response.headers["X-Frame-Options"]).to be_nil
      expect(last_response.body).to eq("App with headers")
    end

    it "removes headers from tidewave routes as well" do
      get "/tidewave/some-sub-route"
      expect(last_response.headers["Content-Security-Policy"]).to be_nil
      expect(last_response.headers["X-Frame-Options"]).to be_nil
    end
  end

  describe "IP validation" do
    context "when remote access is allowed" do
      before do
        config.allow_remote_access = true
      end

      it "allows any IP address" do
        get "/tidewave", {}, { "REMOTE_ADDR" => "192.168.1.100" }
        expect(last_response.status).to eq(200)
      end

      it "allows localhost" do
        get "/tidewave", {}, { "REMOTE_ADDR" => "127.0.0.1" }
        expect(last_response.status).to eq(200)
      end
    end

    context "when remote access is not allowed" do
      before do
        config.allow_remote_access = false
      end

      it "allows localhost" do
        get "/tidewave", {}, { "REMOTE_ADDR" => "127.0.0.1" }
        expect(last_response.status).to eq(200)
      end

      it "rejects remote IP addresses" do
        get "/tidewave", {}, { "REMOTE_ADDR" => "192.168.1.100" }
        expect(last_response.status).to eq(403)
        expect(last_response.headers["Content-Type"]).to eq("text/plain")
        expect(last_response.body).to include("For security reasons, Tidewave does not accept remote connections by default")
        expect(last_response.body).to include("config.tidewave.allow_remote_access = true")
      end
    end
  end

  describe "MCP delegation" do
    context "with allowed access" do
      before do
        config.allow_remote_access = true
      end

      it "delegates SSE route to FastMCP" do
        get "/tidewave/mcp"
        # FastMCP should handle this route, we just verify it doesn't return our home page
        expect(last_response.body).not_to include("<html>")
      end

      it "delegates messages route to FastMCP" do
        post "/tidewave/mcp/message"
        # FastMCP should handle this route, we just verify it doesn't return our home page
        expect(last_response.body).not_to include("<html>")
      end
    end

    context "with IP restrictions" do
      before do
        config.allow_remote_access = false
      end

      it "blocks SSE route for unauthorized IPs" do
        get "/tidewave/mcp", {}, { "REMOTE_ADDR" => "192.168.1.100" }
        expect(last_response.status).to eq(403)
      end

      it "blocks messages route for unauthorized IPs" do
        post "/tidewave/mcp/message", {}, { "REMOTE_ADDR" => "192.168.1.100" }
        expect(last_response.status).to eq(403)
      end
    end
  end

  describe "/tidewave" do
    it "serves home page" do
      config.team = { id: "dashbit" }
      get "/tidewave"
      expect(last_response.status).to eq(200)
      expect(last_response.headers["Content-Type"]).to eq("text/html")
      expect(last_response.body).to include("https://tidewave.ai/tc/tc.js")
      expect(last_response.body).to include("team&quot;:{&quot;id&quot;:&quot;dashbit&quot;}")
    end
  end

  describe "/tidewave/config" do
    it "returns JSON configuration" do
      config.team = { id: "dashbit" }
      get "/tidewave/config"
      expect(last_response.status).to eq(200)
      expect(last_response.headers["Content-Type"]).to eq("application/json")

      parsed_config = JSON.parse(last_response.body)
      expect(parsed_config["framework_type"]).to eq("rails")
      expect(parsed_config["tidewave_version"]).to eq(Tidewave::VERSION)
      expect(parsed_config["team"]).to eq({ "id" => "dashbit" })
      expect(parsed_config).to have_key("project_name")
    end
  end

  describe "/tidewave/shell" do
    def parse_binary_response(body)
      chunks = []
      offset = 0

      while offset < body.bytesize
        type = body.getbyte(offset)
        length = body[offset + 1, 4].unpack1("N")
        data = body[offset + 5, length]
        chunks << { type: type, data: data }
        offset += 5 + length
      end

      chunks
    end

    it "executes simple command and returns output with status" do
      body = { command: "echo 'hello world'" }
      post "/tidewave/shell", JSON.generate(body)
      expect(last_response.status).to eq(200)

      chunks = parse_binary_response(last_response.body)
      expect(chunks.length).to eq(2)

      # First chunk should be stdout data
      expect(chunks[0][:type]).to eq(0)
      expect(chunks[0][:data]).to eq("hello world\n")

      # Second chunk should be status
      expect(chunks[1][:type]).to eq(1)
      status_data = JSON.parse(chunks[1][:data])
      expect(status_data["status"]).to eq(0)
    end

    it "handles command with non-zero exit status" do
      body = { command: "exit 42" }
      post "/tidewave/shell", JSON.generate(body)
      expect(last_response.status).to eq(200)

      chunks = parse_binary_response(last_response.body)
      expect(chunks.length).to eq(1)

      # Should only have status chunk
      expect(chunks[0][:type]).to eq(1)
      status_data = JSON.parse(chunks[0][:data])
      expect(status_data["status"]).to eq(42)
    end

    it "handles multiline commands" do
      body = {
        command: "echo 'line 1'\necho 'line 2'"
      }
      post "/tidewave/shell", JSON.generate(body)
      expect(last_response.status).to eq(200)

      chunks = parse_binary_response(last_response.body)

      # The shell command outputs both lines together
      expect(chunks.length).to eq(2)

      # First chunk should be stdout data with both lines
      expect(chunks[0][:type]).to eq(0)
      expect(chunks[0][:data]).to eq("line 1\nline 2\n")

      # Second chunk should be status
      expect(chunks[1][:type]).to eq(1)
      status_data = JSON.parse(chunks[1][:data])
      expect(status_data["status"]).to eq(0)
    end

    it "returns 400 for empty command body" do
      post "/tidewave/shell", ""
      expect(last_response.status).to eq(400)
      expect(last_response.body).to include("Command body is required")
    end

    it "returns 400 for invalid JSON" do
      post "/tidewave/shell", "not json"
      expect(last_response.status).to eq(400)
      expect(last_response.body).to include("Invalid JSON in request body")
    end

    it "returns 400 for missing command field" do
      body = { other_field: "value" }
      post "/tidewave/shell", JSON.generate(body)
      expect(last_response.status).to eq(400)
      expect(last_response.body).to include("Command field is required")
    end
  end

  describe "edge cases" do
    it "handles trailing slashes" do
      get "/tidewave/"
      expect(last_response.status).to eq(200)
      expect(last_response.body).not_to eq("Downstream App")
    end

    it "handles case sensitivity" do
      get "/TIDEWAVE"
      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq("Downstream App")
    end
  end
end
