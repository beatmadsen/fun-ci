# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/row_formatter"
require "fun_ci/tui/ansi"

class TestRowFormatterFailedRun < Minitest::Test
  def test_should_show_fail_label_on_failed_stage
    # Given a run where fast suite failed
    run_data = make_failed_run
    # When we format it
    result = FunCi::Tui::Ansi.strip(FunCi::Tui::RowFormatter.format(run_data))
    # Then the failed stage should show FAIL with time
    assert_match(/Fast FAIL 6\.2s/, result)
  end

  def test_should_show_dashes_for_unreached_stages
    # Given a run where fast failed (slow never ran)
    run_data = make_failed_run
    # When we format it
    result = FunCi::Tui::Ansi.strip(FunCi::Tui::RowFormatter.format(run_data))
    # Then slow should show --
    assert_match(/Slow --/, result)
  end

  def test_should_show_failed_status
    # Given a failed run
    run_data = make_failed_run
    result = FunCi::Tui::Ansi.strip(FunCi::Tui::RowFormatter.format(run_data))
    assert_match(/FAILED/, result)
  end

  def test_should_color_failed_stage_bold_red
    run_data = make_failed_run
    result = FunCi::Tui::RowFormatter.format(run_data)
    assert_match(/\e\[1;31m.*FAIL/, result, "Failed stage should be bold red")
  end

  private

  def make_failed_run
    now = Time.now.utc
    {
      commit_hash: "91de003", branch: "fix/nil-crash", status: "failed",
      updated_at: now.iso8601,
      stages: [
        { stage: "build", status: "completed", duration: 0.1 },
        { stage: "fast", status: "failed", duration: 6.2 },
        { stage: "slow", status: "scheduled", duration: nil }
      ]
    }
  end
end

class TestRowFormatterTimedOutRun < Minitest::Test
  def test_should_show_timeout_label
    run_data = make_timed_out_run
    result = FunCi::Tui::Ansi.strip(FunCi::Tui::RowFormatter.format(run_data))
    assert_match(/Fast TIMEOUT 10s/, result)
  end

  def test_should_show_timed_out_status
    run_data = make_timed_out_run
    result = FunCi::Tui::Ansi.strip(FunCi::Tui::RowFormatter.format(run_data))
    assert_match(/TIMED OUT/, result)
  end

  def test_should_color_timed_out_bold_yellow
    run_data = make_timed_out_run
    result = FunCi::Tui::RowFormatter.format(run_data)
    assert_match(/\e\[1;33m.*TIMEOUT/, result, "Timed out should be bold yellow")
  end

  private

  def make_timed_out_run
    now = Time.now.utc
    {
      commit_hash: "d4e5f67", branch: "feat/search", status: "timed_out",
      updated_at: now.iso8601,
      stages: [
        { stage: "build", status: "completed", duration: 0.2 },
        { stage: "fast", status: "timed_out", duration: 10.0 },
        { stage: "slow", status: "scheduled", duration: nil }
      ]
    }
  end
end

class TestRowFormatterScheduledRun < Minitest::Test
  def test_should_show_scheduled_text
    run_data = make_scheduled_run
    result = FunCi::Tui::Ansi.strip(FunCi::Tui::RowFormatter.format(run_data))
    assert_match(/Scheduled\.\.\./, result)
  end

  def test_should_not_show_stage_columns
    run_data = make_scheduled_run
    result = FunCi::Tui::Ansi.strip(FunCi::Tui::RowFormatter.format(run_data))
    refute_match(/Build/, result, "Scheduled row should not show stage columns")
    refute_match(/Fast/, result)
    refute_match(/Slow/, result)
  end

  def test_should_be_entirely_dim
    run_data = make_scheduled_run
    result = FunCi::Tui::RowFormatter.format(run_data)
    assert_match(/\e\[2m/, result, "Scheduled row should be dim")
  end

  private

  def make_scheduled_run
    now = Time.now.utc
    {
      commit_hash: "f001ba2", branch: "feat/cache", status: "scheduled",
      updated_at: now.iso8601, stages: []
    }
  end
end

class TestRowFormatterCancelledRun < Minitest::Test
  def test_should_show_cancelled_status
    run_data = make_cancelled_run
    result = FunCi::Tui::Ansi.strip(FunCi::Tui::RowFormatter.format(run_data))
    assert_match(/CANCELLED/, result)
  end

  def test_should_be_dim
    run_data = make_cancelled_run
    result = FunCi::Tui::RowFormatter.format(run_data)
    assert_match(/\e\[2m.*CANCELLED/, result, "CANCELLED should be dim")
  end

  private

  def make_cancelled_run
    now = Time.now.utc
    {
      commit_hash: "d4e5f67", branch: "feat/search", status: "cancelled",
      updated_at: now.iso8601,
      stages: [
        { stage: "build", status: "completed", duration: 0.2 },
        { stage: "fast", status: "cancelled", duration: 7.0 },
        { stage: "slow", status: "scheduled", duration: nil }
      ]
    }
  end
end
