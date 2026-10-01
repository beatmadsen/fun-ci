# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/jobs/state"

# A job's state, read once from its latest run as job_runs keeps it, for
# the console, the agent commands and the trigger alike (design.md, Daily and weekly jobs).
class TestJobState < Minitest::Test
  def test_should_say_a_job_that_never_ran_is_due
    assert_equal "due", FunCi::Jobs::State.of(nil)
  end

  def test_should_say_a_completed_run_passed
    assert_equal "passed", state("completed")
  end

  def test_should_say_a_failed_run_failed
    assert_equal "failed", state("failed")
  end

  def test_should_say_a_run_that_timed_out_ran_over_budget
    assert_equal "over_budget", state("timed_out")
  end

  def test_should_say_a_running_run_runs
    assert_equal "running", state("running", ended: nil)
  end

  def test_should_say_a_cancelled_run_was_cancelled
    assert_equal "cancelled", state("cancelled")
  end

  # Its process died before it said how the run ended.
  def test_should_say_a_failed_run_with_no_end_was_lost
    assert_equal "lost", state("failed", ended: nil)
  end

  # A newer fun-ci sharing the database may have written it.
  def test_should_say_a_status_it_does_not_know_is_unknown
    assert_equal "unknown", state("paused")
  end

  def test_should_say_a_lost_job_needs_you
    assert FunCi::Jobs::State.needs_you?("lost")
  end

  def test_should_say_a_passed_job_does_not_need_you
    refute FunCi::Jobs::State.needs_you?("passed")
  end

  private

  def state(status, ended: "2026-10-01T10:00:00.000Z") = FunCi::Jobs::State.of({ status: status, completed_at: ended })
end
