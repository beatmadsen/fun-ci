# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/row_formatter"
require "fun_ci/tui/ansi"

class TestRowFormatterRunningRun < Minitest::Test
  def test_should_show_running_status
    run_data = make_running_run
    result = FunCi::Tui::Ansi.strip(FunCi::Tui::RowFormatter.format(run_data))
    assert_match(/RUNNING/, result)
  end

  def test_should_show_spinner_on_active_stage
    run_data = make_running_run
    result = FunCi::Tui::Ansi.strip(FunCi::Tui::RowFormatter.format(run_data, spinner_frame: "\u2801"))
    assert_match(/\u2801/, result, "Should show spinner frame on active stage")
  end

  def test_should_show_elapsed_time_on_active_stage
    run_data = make_running_run
    result = FunCi::Tui::Ansi.strip(FunCi::Tui::RowFormatter.format(run_data, elapsed_seconds: 34))
    assert_match(/Slow \S+ 34s/, result, "Should show elapsed time on active stage")
  end

  def test_should_color_active_stage_cyan
    run_data = make_running_run
    result = FunCi::Tui::RowFormatter.format(run_data)
    assert_match(/\e\[36m.*Slow/, result, "Active stage should be cyan")
  end

  def test_should_color_running_status_bold_cyan
    run_data = make_running_run
    result = FunCi::Tui::RowFormatter.format(run_data)
    assert_match(/\e\[1;36m.*RUNNING/, result, "RUNNING should be bold cyan")
  end

  private

  def make_running_run
    now = Time.now.utc
    {
      commit_hash: "c82fa19", branch: "feat/parser", status: "running",
      updated_at: now.iso8601,
      stages: [
        { stage: "build", status: "completed", duration: 0.2 },
        { stage: "fast", status: "completed", duration: 2.4 },
        { stage: "slow", status: "running", duration: nil }
      ]
    }
  end
end
