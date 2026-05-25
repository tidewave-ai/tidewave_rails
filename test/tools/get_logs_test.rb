# frozen_string_literal: true

require "fileutils"
require "pathname"
require "test_helper"
require "tmpdir"

class TidewaveGetLogsTest < Minitest::Test
  def setup
    @tool = Tidewave::Tools::GetLogs.new
    @log_fixture = File.expand_path("../../test/fixtures/fake_development_log.log", __dir__)
  end

  def test_validate_and_call_returns_tail_lines
    with_log_file do |log_file_path|
      result = @tool.validate_and_call({ "tail" => 10 })

      assert_equal File.read(log_file_path).lines.last(10).join, result
    end
  end

  def test_validate_and_call_returns_all_lines_when_tail_exceeds_file
    with_log_file do |log_file_path|
      lines = File.read(log_file_path).lines
      result = @tool.validate_and_call({ "tail" => lines.length + 10 })

      assert_equal lines.join, result
    end
  end

  def test_validate_and_call_filters_logs_with_case_insensitive_regex
    with_log_file do
      result = @tool.validate_and_call({ "tail" => 100, "grep" => "NEVER GONNA" })

      assert result.lines.all? { |line| line.match?(/Never gonna/i) }
      assert_operator result.lines.length, :>, 0
    end
  end

  def test_validate_and_call_respects_tail_after_filtering
    with_log_file do
      result = @tool.validate_and_call({ "tail" => 3, "grep" => "Never gonna" })

      assert_equal 3, result.lines.length
    end
  end

  def test_validate_and_call_returns_message_when_log_file_is_missing
    Dir.mktmpdir do |dir|
      root = Pathname.new(dir)

      Rails.stub(:root, root) do
        Rails.stub(:env, "development") do
          assert_equal "Log file not found", @tool.validate_and_call({ "tail" => 10 })
        end
      end
    end
  end

  private

  def with_log_file
    Dir.mktmpdir do |dir|
      root = Pathname.new(dir)
      log_dir = root.join("log")
      FileUtils.mkdir_p(log_dir)
      log_file_path = log_dir.join("development.log")
      File.write(log_file_path, File.read(@log_fixture))

      Rails.stub(:root, root) do
        Rails.stub(:env, "development") do
          yield log_file_path
        end
      end
    end
  end
end
