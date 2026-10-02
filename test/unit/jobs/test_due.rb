# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/jobs/due"

# When a job is due again, from its latest run alone (acceptance-tests.md, AT-13.3).
class TestJobDue < Minitest::Test
  NOW = Time.utc(2026, 10, 1, 12, 0, 0)
  DAY = 86_400
  WEEK = 604_800

  def test_should_be_due_when_it_never_ran
    assert_predicate due(nil, DAY), :now?
  end

  def test_should_not_be_due_a_minute_short_of_a_day_after_a_daily_run_started
    refute_predicate due(latest("completed", DAY - 60), DAY), :now?
  end

  def test_should_be_due_a_day_after_a_daily_run_started
    assert_predicate due(latest("completed", DAY), DAY), :now?
  end

  def test_should_be_due_a_day_after_a_daily_run_that_failed_started
    assert_predicate due(latest("failed", DAY), DAY), :now?
  end

  def test_should_be_due_at_once_when_its_latest_run_was_cancelled
    assert_predicate due(latest("cancelled", 60), DAY), :now?
  end

  def test_should_not_be_due_six_days_after_a_weekly_run_started
    refute_predicate due(latest("completed", 6 * DAY), WEEK), :now?
  end

  def test_should_be_due_a_week_after_a_weekly_run_started
    assert_predicate due(latest("completed", WEEK), WEEK), :now?
  end

  def test_should_not_be_due_while_its_latest_run_is_running_however_long_ago_it_started
    refute_predicate due(latest("running", 2 * DAY), DAY), :now?
  end

  # A run waiting its turn (Jobs::Schedule) is the job's run: no commit starts another.
  def test_should_not_be_due_while_its_latest_run_waits_to_start
    refute_predicate due(latest("scheduled", 2 * DAY), DAY), :now?
  end

  def test_should_say_nothing_of_when_it_is_due_while_it_waits_to_start
    assert_nil due(latest("scheduled", 60), DAY).at
  end

  def test_should_say_it_is_due_again_a_period_after_its_latest_run_started
    assert_equal NOW + 3600, due(latest("completed", DAY - 3600), DAY).at
  end

  def test_should_say_nothing_of_when_it_is_due_while_it_still_runs
    assert_nil due(latest("running", 60), DAY).at
  end

  def test_should_say_nothing_of_when_it_is_due_while_it_is_due_now
    assert_nil due(nil, DAY).at
  end

  private

  def due(latest, period) = FunCi::Jobs::Due.new(latest, period, now: NOW)
  def latest(status, ago) = { status: status, started_at: (NOW - ago).iso8601(3) }
end
