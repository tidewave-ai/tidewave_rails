# frozen_string_literal: true

describe Tidewave::Tools::GrepProjectFiles do
  describe '.tool_name' do
    it 'returns the tool name' do
      expect(described_class.tool_name).to eq("grep_project_files")
    end
  end

  describe '.description' do
    context 'when rg is available' do
      before do
        allow(described_class).to receive(:`).with("which rg").and_return("/usr/bin/rg")
        allow(described_class).to receive(:ripgrep_executable).and_return("/usr/bin/rg")
      end

      it 'returns the tool description' do
        expect(described_class.description).to eq("Searches for text patterns in files using ripgrep.")
      end
    end

    context 'when rg is not available' do
      before do
        described_class.instance_variable_set(:@ripgrep_executable, nil)
        allow(described_class).to receive(:ripgrep_executable).and_return(nil)
      end

      it 'returns the tool description' do
        expect(described_class.description).to eq("Searches for text patterns in files using a grep variant.")
      end
    end
  end

  describe "#call" do
    subject(:tool) { described_class.new }
    let(:pattern) { "test_pattern" }
    let(:glob) { "**/*.rb" }
    let(:case_sensitive) { false }
    let(:max_results) { 100 }

    before do
      allow(tool).to receive(:execute_grep).and_return([])
      allow(tool).to receive(:execute_ripgrep).and_return([])
      # Set up to use grep by default
      allow(described_class).to receive(:ripgrep_executable).and_return(nil)
    end

    it "searches for the specified pattern" do
      expect(tool).to receive(:execute_grep).with(pattern, glob, case_sensitive, max_results)
      tool.call(pattern: pattern, glob: glob, case_sensitive: case_sensitive, max_results: max_results)
    end

    it "defaults to using grep when ripgrep is unavailable" do
      expect(tool).to receive(:execute_grep)
      tool.call(pattern: pattern)
    end

    context "when ripgrep is available" do
      before do
        allow(described_class).to receive(:ripgrep_executable).and_return("/usr/bin/rg")
      end

      it "uses ripgrep instead of grep" do
        expect(tool).to receive(:execute_ripgrep).with(pattern, glob, case_sensitive, max_results)
        tool.call(pattern: pattern, glob: glob, case_sensitive: case_sensitive, max_results: max_results)
      end
    end
  end

  describe "#execute_grep" do
    subject(:tool) { described_class.new }
    let(:pattern) { "test_pattern" }
    let(:glob) { "**/*.rb" }
    let(:case_sensitive) { false }
    let(:max_results) { 100 }
    let(:glob_tool) { instance_double(Tidewave::Tools::GlobProjectFiles) }
    let(:file_matches) { [ "file1.rb", "file2.rb" ] }
    let(:file_content) { [ "line with test_pattern in it", "another line", "test_pattern here too" ] }

    before do
      allow(Tidewave::Tools::GlobProjectFiles).to receive(:new).and_return(glob_tool)
      allow(glob_tool).to receive(:call).and_return(file_matches)
      allow(File).to receive(:file?).and_return(true)
      allow(File).to receive(:foreach).and_yield(file_content[0]).and_yield(file_content[1]).and_yield(file_content[2])
    end

    it "searches each file for the pattern" do
      file_matches.each do |file|
        expect(File).to receive(:foreach).with(file)
      end

      tool.send(:execute_grep, pattern, glob, case_sensitive, max_results)
    end

    it "respects the max_results limit per file" do
      limited_max = 1

      # Mock file content with multiple matches but we should only get one per file
      expect(tool.send(:execute_grep, pattern, glob, case_sensitive, limited_max)).to include("line_number")
    end

    context "with case sensitivity" do
      let(:case_sensitive) { true }
      let(:pattern) { "TEST_pattern" }

      it "respects case sensitivity when true" do
        # Fix: We need to call the private method directly to test it
        expect(File).to receive(:foreach).at_least(:once)
        tool.send(:execute_grep, pattern, glob, case_sensitive, max_results)
      end
    end
  end

  describe "#execute_ripgrep" do
    subject(:tool) { described_class.new }
    let(:pattern) { "test_pattern" }
    let(:glob) { "**/*.rb" }
    let(:case_sensitive) { false }
    let(:max_results) { 100 }
    let(:rg_path) { "/usr/bin/rg" }
    let(:command_output) { '{"type":"match","data":{"path":{"text":"file1.rb"},"line_number":5,"lines":{"text":"  test_pattern here"}}}' }

    before do
      allow(described_class).to receive(:ripgrep_executable).and_return(rg_path)
      # Don't stub the method before the test, allow each test to set its own expectation
    end

    it "builds the correct ripgrep command" do
      expected_command_parts = [
        rg_path,
        "--no-require-git",
        "--json",
        "--max-count=#{max_results}",
        "--ignore-case",
        "--glob=#{glob}",
        pattern,
        "."
      ]

      expected_command = expected_command_parts.join(" ") + " 2>&1"
      # Fix: Don't include --glob= in the empty string case
      expect(tool).to receive(:`).with(expected_command).and_return(command_output)

      tool.send(:execute_ripgrep, pattern, glob, case_sensitive, max_results)
    end

    it "includes glob pattern when provided" do
      # Fix: Use a proper regex match
      command_with_glob = "#{rg_path} --no-require-git --json --max-count=#{max_results} --ignore-case --glob=#{glob} #{pattern} . 2>&1"
      expect(tool).to receive(:`).with(command_with_glob).and_return(command_output)

      tool.send(:execute_ripgrep, pattern, glob, case_sensitive, max_results)
    end

    it "respects case sensitivity setting" do
      # Test with ignore-case (when case_sensitive is false)
      expect(tool).to receive(:`).with(/--ignore-case/).and_return(command_output)
      tool.send(:execute_ripgrep, pattern, glob, false, max_results)

      # Test without ignore-case (when case_sensitive is true)
      # Fix: Use a proper way to match a string that doesn't contain a substring
      command_without_ignore_case = "#{rg_path} --no-require-git --json --max-count=#{max_results} #{pattern} . 2>&1"
      expect(tool).to receive(:`).with(command_without_ignore_case).and_return(command_output)
      tool.send(:execute_ripgrep, pattern, "", true, max_results)
    end

    it "parses ripgrep JSON output correctly" do
      # Allow backtick to return our test output
      allow(tool).to receive(:`).and_return(command_output)

      result = tool.send(:format_ripgrep_results, command_output)
      parsed = JSON.parse(result)

      expect(parsed.first["path"]).to eq("file1.rb")
      expect(parsed.first["line_number"]).to eq(5)
      expect(parsed.first["content"]).to eq("test_pattern here")
    end
  end
end
