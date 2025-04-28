# frozen_string_literal: true

require "rails_helper"
require "spec_helper"
require "tidewave/tool_resolver"

describe Tidewave::ToolResolver do
  let(:app) { ->(env) { [ 200, {}, [ "OK" ] ] } }
  let(:server) { instance_double(FastMcp::Server) }
  let(:middleware) { described_class.new(app, server) }
  let(:env) { Rack::MockRequest.env_for(request_path, params: params, method: method, input: body) }
  let(:request_path) { described_class::MESSAGES_PATH }
  let(:params) { {} }
  let(:body) { JSON.generate(request_body) }
  let(:request_body) { { "method" => described_class::TOOLS_LIST_METHOD } }
  let(:method) { "POST" }

  before do
    allow(server).to receive(:register_tools)
    allow(server).to receive(:instance_variable_set)
  end

  describe "#call" do
    subject { middleware.call(env) }

    context "when the path is not the MESSAGES_PATH" do
      let(:request_path) { "/some/other/path" }

      it "forwards the request without modifying tools" do
        expect(server).not_to receive(:register_tools)
        expect(subject).to eq([ 200, {}, [ "OK" ] ])
      end
    end

    context "when the path is the MESSAGES_PATH" do
      context "but not requesting tools/list" do
        let(:request_body) { { "method" => "something_else" } }

        it "forwards the request without modifying tools" do
          expect(server).not_to receive(:register_tools)
          expect(subject).to eq([ 200, {}, [ "OK" ] ])
        end
      end

      context "when requesting tools/list" do
        context "without include_fs_tools parameter" do
          it "registers only non-file system tools then all tools afterward" do
            expect(server).to receive(:instance_variable_set).with(:@tools, {})
            expect(server).to receive(:register_tools).with(*Tidewave::ToolResolver::NON_FILE_SYSTEM_TOOLS)
            expect(server).to receive(:instance_variable_set).with(:@tools, {})
            expect(server).to receive(:register_tools).with(*Tidewave::ToolResolver::ALL_TOOLS)
            expect(subject).to eq([ 200, {}, [ "OK" ] ])
          end
        end

        context "with include_fs_tools=false" do
          let(:params) { { "include_fs_tools" => "false" } }

          it "registers only non-file system tools then all tools afterward" do
            expect(server).to receive(:instance_variable_set).with(:@tools, {})
            expect(server).to receive(:register_tools).with(*Tidewave::ToolResolver::NON_FILE_SYSTEM_TOOLS)
            expect(server).to receive(:instance_variable_set).with(:@tools, {})
            expect(server).to receive(:register_tools).with(*Tidewave::ToolResolver::ALL_TOOLS)
            expect(subject).to eq([ 200, {}, [ "OK" ] ])
          end
        end

        context "with include_fs_tools=true" do
          let(:params) { { "include_fs_tools" => "true" } }

          # The issue is in the implementation - it uses params from the request
          # to check include_fs_tools, but then checks the method from the JSON body
          it "registers only non-file system tools then all tools afterward" do
            expect(server).to receive(:instance_variable_set).with(:@tools, {}).twice
            expect(server).to receive(:register_tools).with(*Tidewave::ToolResolver::NON_FILE_SYSTEM_TOOLS)
            expect(server).to receive(:register_tools).with(*Tidewave::ToolResolver::ALL_TOOLS)
            expect(subject).to eq([ 200, {}, [ "OK" ] ])
          end
        end
      end
    end
  end

  describe "class constants" do
    it "correctly identifies file system tools" do
      file_system_tools = Tidewave::ToolResolver::ALL_TOOLS - Tidewave::ToolResolver::NON_FILE_SYSTEM_TOOLS

      # All tools in file_system_tools should have file_system_tool? return true
      file_system_tools.each do |tool|
        expect(tool.file_system_tool?).to be(true), "Expected #{tool} to be a file system tool"
      end

      # All tools in NON_FILE_SYSTEM_TOOLS should have file_system_tool? return false or nil
      Tidewave::ToolResolver::NON_FILE_SYSTEM_TOOLS.each do |tool|
        expect(tool.file_system_tool?).to be_falsey, "Expected #{tool} not to be a file system tool"
      end
    end
  end
end
