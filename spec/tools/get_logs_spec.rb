# frozen_string_literal: true

require 'rails'

describe Tidewave::Tools::GetLogs do
  describe ".tool_name" do
    it "returns the correct tool name" do
      expect(described_class.tool_name).to eq("get_logs")
    end
  end

  describe "#call" do
    let(:log_file_path) { "spec/fixtures/fake_development_log.log" }
    let(:log_file_content) { File.read(log_file_path) }

    before do
      allow(Rails).to receive_message_chain(:root, :join).and_return(Pathname.new(log_file_path))
    end

    context "without grep filter" do
      it "returns the correct logs" do
        expect(described_class.new.call(tail: 10)).to eq(log_file_content.lines.last(10).join)
      end

      it "returns all lines when tail is larger than file" do
        total_lines = log_file_content.lines.count
        expect(described_class.new.call(tail: total_lines + 10)).to eq(log_file_content)
      end
    end

    context "with grep filter" do
      it "filters logs with the given regular expression" do
        result = described_class.new.call(tail: 100, grep: "Never gonna")
        lines = result.lines

        expect(lines.all? { |line| line.match?(/Never gonna/) }).to be true
        expect(lines.size).to be > 0
      end

      it "respects tail limit after filtering" do
        result = described_class.new.call(tail: 3, grep: "Never gonna")
        lines = result.lines
        expect(lines.size).to eq(3)
      end

      it "works with case-insensitive regex" do
        result = described_class.new.call(tail: 100, grep: "NEVER GONNA")
        lines = result.lines

        expect(lines.all? { |line| line.match?(/Never gonna/i) }).to be true
        expect(lines.size).to be > 0
      end

      it "works with complex regex patterns" do
        result = described_class.new.call(tail: 100, grep: "never gonna (give|let)")
        lines = result.lines

        expect(lines.all? { |line| line.match?(/Never gonna (give|let)/i) }).to be true
        expect(lines.size).to be > 0
      end
    end

    context "when log file doesn't exist" do
      before do
        allow(Rails).to receive_message_chain(:root, :join).and_return(Pathname.new("nonexistent.log"))
      end

      it "returns appropriate message" do
        expect(described_class.new.call(tail: 10)).to eq("Log file not found")
      end
    end
  end
end
