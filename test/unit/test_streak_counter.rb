# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/streak_counter"

class TestStreakCounter < Minitest::Test
  def test_should_count_consecutive_passes
    # Given 7 consecutive passed runs (most recent first)
    runs = Array.new(7) { { status: "completed" } }
    # When we count the streak
    result = FunCi::Tui::StreakCounter.count(runs)
    # Then the streak should be 7
    assert_equal 7, result, "Should count all consecutive completed runs"
  end

  def test_should_stop_at_first_failure
    # Given 3 passed then 1 failed then 2 passed (most recent first)
    runs = [
      { status: "completed" },
      { status: "completed" },
      { status: "completed" },
      { status: "failed" },
      { status: "completed" },
      { status: "completed" }
    ]
    # When we count the streak
    result = FunCi::Tui::StreakCounter.count(runs)
    # Then the streak should be 3
    assert_equal 3, result, "Should stop counting at first non-pass"
  end

  def test_should_return_zero_when_most_recent_failed
    # Given the most recent run failed
    runs = [{ status: "failed" }, { status: "completed" }]
    # When we count the streak
    result = FunCi::Tui::StreakCounter.count(runs)
    # Then the streak should be 0
    assert_equal 0, result, "Streak is 0 when most recent run failed"
  end

  def test_should_return_zero_when_most_recent_timed_out
    # Given the most recent run timed out
    runs = [{ status: "timed_out" }, { status: "completed" }]
    # When we count the streak
    result = FunCi::Tui::StreakCounter.count(runs)
    # Then the streak should be 0
    assert_equal 0, result, "Streak is 0 when most recent run timed out"
  end

  def test_should_skip_running_pipelines
    # Given a running pipeline followed by 4 passed runs
    runs = [
      { status: "running" },
      { status: "completed" },
      { status: "completed" },
      { status: "completed" },
      { status: "completed" }
    ]
    # When we count the streak
    result = FunCi::Tui::StreakCounter.count(runs)
    # Then the streak should be 4 (running doesn't affect it)
    assert_equal 4, result, "Running pipelines should be skipped"
  end

  def test_should_skip_scheduled_pipelines
    # Given scheduled pipelines followed by passed runs
    runs = [
      { status: "scheduled" },
      { status: "running" },
      { status: "completed" },
      { status: "completed" }
    ]
    # When we count the streak
    result = FunCi::Tui::StreakCounter.count(runs)
    # Then the streak should be 2
    assert_equal 2, result, "Scheduled pipelines should be skipped"
  end

  def test_should_return_nil_for_empty_list
    # Given no runs
    result = FunCi::Tui::StreakCounter.count([])
    # Then the streak should be nil (no runs to count)
    assert_nil result, "Empty list means no completed runs, so nil"
  end

  def test_should_format_streak_text_for_passing
    # Given a streak of 7
    result = FunCi::Tui::StreakCounter.format_text(7)
    # Then it should say "7 in a row!"
    assert_equal "7 in a row!", result
  end

  def test_should_format_streak_broken_for_zero
    # Given a streak of 0 with completed runs existing
    result = FunCi::Tui::StreakCounter.format_text(0)
    # Then it should say "Streak broken"
    assert_equal "Streak broken", result
  end

  def test_should_return_nil_text_when_no_completed_runs
    # Given nil (indicating no completed runs at all)
    result = FunCi::Tui::StreakCounter.format_text(nil)
    # Then it should return nil (no streak to show)
    assert_nil result, "No text when no completed runs exist"
  end

  def test_should_count_returns_nil_when_no_terminal_runs
    # Given only running/scheduled runs
    runs = [{ status: "running" }, { status: "scheduled" }]
    # When we count the streak
    result = FunCi::Tui::StreakCounter.count(runs)
    # Then it should return nil (no completed runs to count)
    assert_nil result, "Should return nil when no terminal runs exist"
  end
end
