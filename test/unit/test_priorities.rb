# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/priorities"

# What jobs and the slow suite start under, so they give way to the stages a
# push waits for (AT-13.27). On macOS nice barely moves the scheduler, and a
# QoS clamp of utility lets a job have every idle core yet yield to stages;
# the slow suite there is left as it is, since clamped beside clamped jobs it
# crawls. Elsewhere nice does it.
class TestPriorities < Minitest::Test
  def test_should_clamp_a_job_to_utility_on_macos
    assert_equal "taskpolicy -c utility ", FunCi::Pipeline::Priorities.for("arm64-darwin24").job
  end

  def test_should_leave_the_slow_suite_as_it_is_on_macos
    assert_equal "", FunCi::Pipeline::Priorities.for("x86_64-darwin23").slow
  end

  def test_should_run_a_job_at_the_lowest_priority_elsewhere
    assert_equal "nice -n 19 ", FunCi::Pipeline::Priorities.for("x86_64-linux").job
  end

  # Below the fast suite beside it, above any job.
  def test_should_run_the_slow_suite_between_the_stages_and_the_jobs_elsewhere
    assert_equal "nice -n 10 ", FunCi::Pipeline::Priorities.for("aarch64-linux-musl").slow
  end
end
