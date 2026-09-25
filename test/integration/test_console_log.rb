# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/console/console_log"
require "tmpdir"

# Where the console writes what the renderer got wrong, since the terminal
# belongs to the renderer and stderr would draw over it.
class TestConsoleLog < Minitest::Test
  def setup
    @project = Dir.mktmpdir
    two_pm_in_copenhagen = Time.new(2026, 9, 25, 14, 0, 5, "+02:00")
    @log = FunCi::Console::ConsoleLog.new(project_dir: @project, clock: -> { two_pm_in_copenhagen })
  end

  def teardown = FileUtils.rm_rf(@project)

  def lines = File.readlines(File.join(@project, ".fun-ci", "console.log"), chomp: true)

  def test_should_write_the_line_to_the_project_s_console_log
    @log.write("renderer error terminal: no tty")

    assert_match(/renderer error terminal: no tty\z/, lines.last)
  end

  def test_should_stamp_the_line_with_the_clock_s_time_in_utc
    @log.write("x")

    assert_equal "2026-09-25T12:00:05Z x", lines.last
  end

  def test_should_keep_the_lines_written_before
    @log.write("first")
    @log.write("second")

    assert_equal 2, lines.size
  end
end
