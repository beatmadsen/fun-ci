# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/console/streak_counter"

# Runs are listed most recent first.
class TestStreakCounter < Minitest::Test
  def test_should_count_consecutive_passes
    assert_equal 7, streak(*Array.new(7, "completed")), "Should count all consecutive completed runs"
  end

  def test_should_stop_at_first_failure
    result = streak("completed", "completed", "completed", "failed", "completed", "completed")
    assert_equal 3, result, "Should stop counting at first non-pass"
  end

  def test_should_return_zero_when_most_recent_failed
    assert_equal 0, streak("failed", "completed"), "Streak is 0 when most recent run failed"
  end

  def test_should_return_zero_when_most_recent_timed_out
    assert_equal 0, streak("timed_out", "completed"), "Streak is 0 when most recent run timed out"
  end

  def test_should_skip_running_pipelines
    result = streak("running", "completed", "completed", "completed", "completed")
    assert_equal 4, result, "Running pipelines should be skipped"
  end

  def test_should_skip_scheduled_pipelines
    result = streak("scheduled", "running", "completed", "completed")
    assert_equal 2, result, "Scheduled pipelines should be skipped"
  end

  def test_should_return_nil_for_empty_list
    assert_nil streak, "Empty list means no completed runs, so nil"
  end

  def test_should_format_streak_text_for_passing
    assert_equal "7 in a row!", FunCi::Console::StreakCounter.format_text(7)
  end

  def test_should_format_streak_broken_for_zero
    assert_equal "Streak broken", FunCi::Console::StreakCounter.format_text(0)
  end

  def test_should_return_nil_text_when_no_completed_runs
    assert_nil FunCi::Console::StreakCounter.format_text(nil), "No text when no completed runs exist"
  end

  def test_should_count_returns_nil_when_no_terminal_runs
    assert_nil streak("running", "scheduled"), "Should return nil when no terminal runs exist"
  end

  private

  def streak(*statuses)
    FunCi::Console::StreakCounter.count(statuses.map { |status| { status: status } })
  end
end
