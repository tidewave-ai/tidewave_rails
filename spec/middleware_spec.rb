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

  describe "/tidewave" do
    it "serves home page" do
      get "/tidewave"
      expect(last_response.status).to eq(200)
      expect(last_response.headers["Content-Type"]).to eq("text/html")
      expect(last_response.body).to include("Welcome to Tidewave")
      expect(last_response.body).to include("<title>Tidewave</title>")
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