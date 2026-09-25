# frozen_string_literal: true

require_relative "../test_helper"
require_relative "row_formatter_runs"

class TestRowFormatterFailedRun < Minitest::Test
  include RowFormatterRuns

  def test_should_show_fail_label_on_failed_stage
    assert_match(/Fast FAIL 6\.2s/, plain_formatted(make_failed_run))
  end

  def test_should_show_dashes_for_unreached_stages
    assert_match(/Slow --/, plain_formatted(make_failed_run))
  end

  def test_should_show_failed_status
    assert_match(/FAILED/, plain_formatted(make_failed_run))
  end

  def test_should_color_failed_stage_bold_red
    assert_match(/\e\[1;31m.*FAIL/, formatted(make_failed_run), "Failed stage should be bold red")
  end

  private

  def make_failed_run
    make_run("91de003", "fix/nil-crash", "failed",
             [["build", "completed", 0.1], ["fast", "failed", 6.2], ["slow", "scheduled", nil]])
  end
end

class TestRowFormatterTimedOutRun < Minitest::Test
  include RowFormatterRuns

  def test_should_show_timeout_label
    assert_match(/Fast TIMEOUT 10s/, plain_formatted(make_timed_out_run))
  end

  def test_should_show_timed_out_status
    assert_match(/TIMED OUT/, plain_formatted(make_timed_out_run))
  end

  def test_should_color_timed_out_bold_yellow
    assert_match(/\e\[1;33m.*TIMEOUT/, formatted(make_timed_out_run), "Timed out should be bold yellow")
  end

  private

  def make_timed_out_run
    make_run("d4e5f67", "feat/search", "timed_out",
             [["build", "completed", 0.2], ["fast", "timed_out", 10.0], ["slow", "scheduled", nil]])
  end
end

class TestRowFormatterScheduledRun < Minitest::Test
  include RowFormatterRuns

  def test_should_show_scheduled_text
    assert_match(/Scheduled\.\.\./, plain_formatted(make_scheduled_run))
  end

  def test_should_not_show_stage_columns
    result = plain_formatted(make_scheduled_run)
    refute_match(/Build/, result, "Scheduled row should not show stage columns")
    refute_match(/Fast/, result)
    refute_match(/Slow/, result)
  end

  def test_should_be_entirely_dim
    assert_match(/\e\[2m/, formatted(make_scheduled_run), "Scheduled row should be dim")
  end

  private

  def make_scheduled_run
    make_run("f001ba2", "feat/cache", "scheduled")
  end
end

class TestRowFormatterCancelledRun < Minitest::Test
  include RowFormatterRuns

  def test_should_show_cancelled_status
    assert_match(/CANCELLED/, plain_formatted(make_cancelled_run))
  end

  def test_should_be_dim
    assert_match(/\e\[2m.*CANCELLED/, formatted(make_cancelled_run), "CANCELLED should be dim")
  end

  private

  def make_cancelled_run
    make_run("d4e5f67", "feat/search", "cancelled",
             [["build", "completed", 0.2], ["fast", "cancelled", 7.0], ["slow", "scheduled", nil]])
  end
end
