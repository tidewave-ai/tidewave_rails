# frozen_string_literal: true

require "pathname"
require "test_helper"
require "tmpdir"

class TidewaveGetLogsTest < Minitest::Test
  def setup
    @log_fixture = File.expand_path("../../test/fixtures/fake_development_log.log", __dir__)
  end

  def test_validate_and_call_returns_tail_lines
    with_log_file do |tool, log_file_path|
      result = tool.validate_and_call({ "tail" => 10 })

      assert_equal File.read(log_file_path).lines.last(10).join, result
    end
  end

  def test_validate_and_call_returns_all_lines_when_tail_exceeds_file
    with_log_file do |tool, log_file_path|
      lines = File.read(log_file_path).lines
      result = tool.validate_and_call({ "tail" => lines.length + 10 })

      assert_equal lines.join, result
    end
  end

  def test_validate_and_call_filters_logs_with_case_insensitive_regex
    with_log_file do |tool|
      result = tool.validate_and_call({ "tail" => 100, "grep" => "NEVER GONNA" })

      assert result.lines.all? { |line| line.match?(/Never gonna/i) }
      assert_operator result.lines.length, :>, 0
    end
  end

  def test_validate_and_call_respects_tail_after_filtering
    with_log_file do |tool|
      result = tool.validate_and_call({ "tail" => 3, "grep" => "Never gonna" })

      assert_equal 3, result.lines.length
    end
  end

  def test_validate_and_call_returns_message_when_log_file_is_missing
    Dir.mktmpdir do |dir|
      log_file = Pathname.new(dir).join("missing.log")
      tool = Tidewave::Tools::GetLogs.new(log_file: log_file)

      assert_equal "Log file not found", tool.validate_and_call({ "tail" => 10 })
    end
  end

  def test_definition_is_present_when_log_file_is_configured_but_missing
    Dir.mktmpdir do |dir|
      log_file = Pathname.new(dir).join("missing.log")
      tool = Tidewave::Tools::GetLogs.new(log_file: log_file)

      assert_equal "get_logs", tool.definition["name"]
    end
  end

  def test_definition_is_nil_when_log_file_is_not_configured
    tool = Tidewave::Tools::GetLogs.new

    assert_nil tool.definition
  end

  private

  def with_log_file
    Dir.mktmpdir do |dir|
      log_file_path = Pathname.new(dir).join("development.log")
      File.write(log_file_path, File.read(@log_fixture))
      tool = Tidewave::Tools::GetLogs.new(log_file: log_file_path)
      yield tool, log_file_path
    end
  end
end
