# frozen_string_literal: true

require "rack/test"

RSpec.describe Tidewave::ExceptionsMiddleware do
  include Rack::Test::Methods

  describe "exception handling" do
    context "when exception is present" do
      let(:downstream_app) do
        lambda do |env|
          request = ActionDispatch::Request.new(env)
          exception = RuntimeError.new("Test error message")
          exception.set_backtrace([
            "/app/controllers/test_controller.rb:10:in `show'",
            "/app/lib/some_lib.rb:20:in `process'"
          ])
          request.set_header("tidewave.exception", exception)

          [ 200, { "Content-Type" => "text/html" }, [ "<html><body><h1>Error Page</h1></body></html>" ] ]
        end
      end

      let(:middleware) { described_class.new(downstream_app) }

      def app
        middleware
      end

      it "includes exception info in response body" do
        # Mock Rails.backtrace_cleaner to return the same backtrace
        backtrace_cleaner = double("backtrace_cleaner")
        allow(Rails).to receive(:backtrace_cleaner).and_return(backtrace_cleaner)
        allow(backtrace_cleaner).to receive(:clean).and_return([
          "/app/controllers/test_controller.rb:10:in `show'",
          "/app/lib/some_lib.rb:20:in `process'"
        ])

        get "/", {}, { "action_dispatch.request.path_parameters" => { "controller" => "test", "action" => "show" } }

        expect(last_response.status).to eq(200)

        expect(last_response.body).to include(<<~TEXT.chomp)
        <pre style="display: none;" data-tidewave-exception-info><code>RuntimeError in TestController#show

        ## Message

        Test error message

        ## Backtrace

        /app/controllers/test_controller.rb:10:in `show&#39;
        /app/lib/some_lib.rb:20:in `process&#39;

        ## Request info

          * URI: http://example.org/
          * Query string:\s

        ## Session

            {}</code></pre>
        TEXT
      end

      it "handles exceptions without controller/action parameters" do
        backtrace_cleaner = double("backtrace_cleaner")
        allow(Rails).to receive(:backtrace_cleaner).and_return(backtrace_cleaner)
        allow(backtrace_cleaner).to receive(:clean).and_return([])

        get "/"

        expect(last_response.status).to eq(200)
        expect(last_response.body).to include("RuntimeError")
        expect(last_response.body).not_to include("Controller")
      end

      it "handles exceptions without backtrace" do
        # Mock Rails.backtrace_cleaner to return empty array
        backtrace_cleaner = double("backtrace_cleaner")
        allow(Rails).to receive(:backtrace_cleaner).and_return(backtrace_cleaner)
        allow(backtrace_cleaner).to receive(:clean).and_return([])

        get "/"

        expect(last_response.status).to eq(200)
        expect(last_response.body).to include("RuntimeError")
        expect(last_response.body).not_to include("## Backtrace")
      end
    end

    context "when no exception is present" do
      let(:downstream_app) { ->(env) { [ 200, { "Content-Type" => "text/html" }, [ "<html><body><h1>Hello World</h1></body></html>" ] ] } }
      let(:middleware) { described_class.new(downstream_app) }

      def app
        middleware
      end

      it "does not modify response" do
        get "/"

        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq("<html><body><h1>Hello World</h1></body></html>")
        expect(last_response.body).not_to include("data-tidewave-exception-info")
      end
    end
  end
end
