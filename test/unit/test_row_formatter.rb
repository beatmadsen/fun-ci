# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/row_formatter"
require "fun_ci/ansi"

class TestRowFormatterPassedRun < Minitest::Test
  def test_should_show_commit_and_branch
    # Given a passed pipeline run
    run_data = make_passed_run
    # When we format it
    result = FunCi::Ansi.strip(FunCi::RowFormatter.format(run_data))
    # Then it should contain commit and branch
    assert_match(/a3f7c01/, result, "Should show commit hash")
    assert_match(/main/, result, "Should show branch name")
  end

  def test_should_show_stage_times
    # Given a passed pipeline run
    run_data = make_passed_run
    # When we format it
    result = FunCi::Ansi.strip(FunCi::RowFormatter.format(run_data))
    # Then it should show all three stage times
    assert_match(/Build 0\.3s/, result, "Should show build time")
    assert_match(/Fast 1\.8s/, result, "Should show fast time")
    assert_match(/Slow 47s/, result, "Should show slow time")
  end

  def test_should_show_passed_status
    # Given a passed pipeline run
    run_data = make_passed_run
    # When we format it
    result = FunCi::Ansi.strip(FunCi::RowFormatter.format(run_data))
    # Then it should show PASSED status
    assert_match(/PASSED/, result)
  end

  def test_should_show_relative_time
    # Given a passed pipeline run
    run_data = make_passed_run
    # When we format it
    result = FunCi::Ansi.strip(FunCi::RowFormatter.format(run_data, now: Time.parse(run_data[:updated_at]) + 120))
    # Then it should show relative time
    assert_match(/2m ago/, result)
  end

  def test_should_color_stage_times_green
    # Given a passed pipeline run
    run_data = make_passed_run
    # When we format it (with color)
    result = FunCi::RowFormatter.format(run_data)
    # Then it should contain green ANSI codes
    assert_match(/\e\[32m.*Build/, result, "Stage times should be green")
  end

  def test_should_color_passed_status_bold_green
    # Given a passed pipeline run
    run_data = make_passed_run
    # When we format it (with color)
    result = FunCi::RowFormatter.format(run_data)
    # Then status should be bold green
    assert_match(/\e\[1;32m.*PASSED/, result, "PASSED should be bold green")
  end

  private

  def make_passed_run
    now = Time.now.utc
    {
      commit_hash: "a3f7c01", branch: "main", status: "completed",
      updated_at: now.iso8601,
      stages: [
        { stage: "build", status: "completed", duration: 0.3 },
        { stage: "fast", status: "completed", duration: 1.8 },
        { stage: "slow", status: "completed", duration: 47.0 }
      ]
    }
  end
end

class TestRowFormatterFailedRun < Minitest::Test
  def test_should_show_fail_label_on_failed_stage
    # Given a run where fast suite failed
    run_data = make_failed_run
    # When we format it
    result = FunCi::Ansi.strip(FunCi::RowFormatter.format(run_data))
    # Then the failed stage should show FAIL with time
    assert_match(/Fast FAIL 6\.2s/, result)
  end

  def test_should_show_dashes_for_unreached_stages
    # Given a run where fast failed (slow never ran)
    run_data = make_failed_run
    # When we format it
    result = FunCi::Ansi.strip(FunCi::RowFormatter.format(run_data))
    # Then slow should show --
    assert_match(/Slow --/, result)
  end

  def test_should_show_failed_status
    # Given a failed run
    run_data = make_failed_run
    result = FunCi::Ansi.strip(FunCi::RowFormatter.format(run_data))
    assert_match(/FAILED/, result)
  end

  def test_should_color_failed_stage_bold_red
    run_data = make_failed_run
    result = FunCi::RowFormatter.format(run_data)
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
    result = FunCi::Ansi.strip(FunCi::RowFormatter.format(run_data))
    assert_match(/Fast TIMEOUT 10s/, result)
  end

  def test_should_show_timed_out_status
    run_data = make_timed_out_run
    result = FunCi::Ansi.strip(FunCi::RowFormatter.format(run_data))
    assert_match(/TIMED OUT/, result)
  end

  def test_should_color_timed_out_bold_yellow
    run_data = make_timed_out_run
    result = FunCi::RowFormatter.format(run_data)
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
    result = FunCi::Ansi.strip(FunCi::RowFormatter.format(run_data))
    assert_match(/Scheduled\.\.\./, result)
  end

  def test_should_not_show_stage_columns
    run_data = make_scheduled_run
    result = FunCi::Ansi.strip(FunCi::RowFormatter.format(run_data))
    refute_match(/Build/, result, "Scheduled row should not show stage columns")
    refute_match(/Fast/, result)
    refute_match(/Slow/, result)
  end

  def test_should_be_entirely_dim
    run_data = make_scheduled_run
    result = FunCi::RowFormatter.format(run_data)
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
    result = FunCi::Ansi.strip(FunCi::RowFormatter.format(run_data))
    assert_match(/CANCELLED/, result)
  end

  def test_should_be_dim
    run_data = make_cancelled_run
    result = FunCi::RowFormatter.format(run_data)
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

class TestRowFormatterRunningRun < Minitest::Test
  def test_should_show_running_status
    run_data = make_running_run
    result = FunCi::Ansi.strip(FunCi::RowFormatter.format(run_data))
    assert_match(/RUNNING/, result)
  end

  def test_should_show_spinner_on_active_stage
    run_data = make_running_run
    result = FunCi::Ansi.strip(FunCi::RowFormatter.format(run_data, spinner_frame: "\u2801"))
    assert_match(/\u2801/, result, "Should show spinner frame on active stage")
  end

  def test_should_show_elapsed_time_on_active_stage
    run_data = make_running_run
    result = FunCi::Ansi.strip(FunCi::RowFormatter.format(run_data, elapsed_seconds: 34))
    assert_match(/Slow \S+ 34s/, result, "Should show elapsed time on active stage")
  end

  def test_should_color_active_stage_cyan
    run_data = make_running_run
    result = FunCi::RowFormatter.format(run_data)
    assert_match(/\e\[36m.*Slow/, result, "Active stage should be cyan")
  end

  def test_should_color_running_status_bold_cyan
    run_data = make_running_run
    result = FunCi::RowFormatter.format(run_data)
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
