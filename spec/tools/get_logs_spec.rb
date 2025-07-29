# frozen_string_literal: true

require 'rails'

describe Tidewave::Tools::GetLogs do
  describe ".tool_name" do
    it "returns the correct tool name" do
      expect(described_class.tool_name).to eq("get_logs")
    end
  end

  describe ".description" do
    it "returns the correct description" do
      expect(described_class.description).to eq(
        <<~DESCRIPTION
          Returns all log output, excluding logs that were caused by other tool calls.

          Use this tool to check for request logs or potentially logged errors.
        DESCRIPTION
      )
    end
  end

  describe "#call" do
    let(:log_file_path) { "spec/fixtures/fake_development_log.log" }
    let(:log_file_content) { File.read(log_file_path) }

    it "returns the correct logs" do
      allow(Rails).to receive_message_chain(:root, :join).and_return(Pathname.new(log_file_path))
      expect(described_class.new.call(tail: 10)).to eq(log_file_content.lines.last(10).join)
    end
  end
end
