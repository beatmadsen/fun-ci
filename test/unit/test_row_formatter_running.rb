# frozen_string_literal: true

require_relative "../test_helper"
require_relative "row_formatter_runs"

class TestRowFormatterRunningRun < Minitest::Test
  include RowFormatterRuns

  def test_should_show_running_status
    assert_match(/RUNNING/, plain_formatted(make_running_run))
  end

  def test_should_show_spinner_on_active_stage
    result = plain_formatted(make_running_run, spinner_frame: "⠁")
    assert_match(/⠁/, result, "Should show spinner frame on active stage")
  end

  def test_should_show_elapsed_time_on_active_stage
    result = plain_formatted(make_running_run, elapsed_seconds: 34)
    assert_match(/Slow \S+ 34s/, result, "Should show elapsed time on active stage")
  end

  def test_should_color_active_stage_cyan
    assert_match(/\e\[36m.*Slow/, formatted(make_running_run), "Active stage should be cyan")
  end

  def test_should_color_running_status_bold_cyan
    assert_match(/\e\[1;36m.*RUNNING/, formatted(make_running_run), "RUNNING should be bold cyan")
  end

  private

  def make_running_run
    make_run("c82fa19", "feat/parser", "running",
             [["build", "completed", 0.2], ["fast", "completed", 2.4], ["slow", "running", nil]])
  end
end
