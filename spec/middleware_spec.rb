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
      ->(env) { [ 200, { "X-Frame-Options" => "DENY" }, [ "App with headers" ] ] }
    end

    def app
      described_class.new(downstream_app_with_headers, config)
    end

    it "removes X-Frame-Options headers from all responses" do
      get "/some-route"
      expect(last_response.status).to eq(200)
      expect(last_response.headers["X-Frame-Options"]).to be_nil
      expect(last_response.body).to eq("App with headers")
    end

    it "removes headers from tidewave routes as well" do
      get "/tidewave/some-sub-route"
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

  describe "MCP endpoint" do
    context "with allowed access" do
      before do
        config.allow_remote_access = true
      end

      it "returns 405 Method Not Allowed for GET requests (no SSE)" do
        get "/tidewave/mcp"
        expect(last_response.status).to eq(405)
        expect(last_response.headers["Content-Type"]).to eq("application/json")

        body = JSON.parse(last_response.body)
        expect(body["error"]["code"]).to eq(-32601)
        expect(body["error"]["message"]).to include("Method not allowed")
      end

      it "handles POST requests to MCP endpoint" do
        # Send a valid JSON-RPC 2.0 ping request
        request_body = {
          jsonrpc: "2.0",
          method: "ping",
          id: 1
        }

        post "/tidewave/mcp", JSON.generate(request_body), { "CONTENT_TYPE" => "application/json" }
        expect(last_response.status).to eq(200)
        expect(last_response.headers["Content-Type"]).to eq("application/json")

        # Should get a valid JSON-RPC response
        body = JSON.parse(last_response.body)
        expect(body["jsonrpc"]).to eq("2.0")
        expect(body["id"]).to eq(1)
      end
    end

    context "with IP restrictions" do
      before do
        config.allow_remote_access = false
      end

      it "blocks GET requests for unauthorized IPs" do
        get "/tidewave/mcp", {}, { "REMOTE_ADDR" => "192.168.1.100" }
        expect(last_response.status).to eq(403)
      end

      it "blocks POST requests for unauthorized IPs" do
        post "/tidewave/mcp", JSON.generate({ jsonrpc: "2.0", method: "ping", id: 1 }), { "REMOTE_ADDR" => "192.168.1.100" }
        expect(last_response.status).to eq(403)
      end
    end
  end

  describe "/tidewave" do
    it "serves home page" do
      get "/tidewave"
      expect(last_response.status).to eq(200)
      expect(last_response.headers["Content-Type"]).to eq("text/html")
      expect(last_response.body).to include("https://tidewave.ai/tc/tc.js")
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
