# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/agent/verdict"

class TestVerdict < Minitest::Test
  def test_should_pass_when_every_needed_stage_passed
    assert_equal :passed, decide("fast", lint: "completed", build: "completed", fast: "completed", slow: "running")
  end

  def test_should_be_undecided_while_a_needed_stage_runs
    assert_equal :undecided, decide("fast", lint: "completed", build: "completed", fast: "running")
  end

  def test_should_be_undecided_while_a_needed_stage_has_not_started
    assert_equal :undecided, decide("fast", lint: "completed", build: "completed")
  end

  def test_should_fail_when_a_needed_stage_failed
    assert_equal :failed, decide("all", lint: "completed", build: "failed")
  end

  def test_should_be_over_budget_when_a_needed_stage_ran_out_of_time
    assert_equal :over_budget, decide("fast", lint: "completed", build: "completed", fast: "timed_out")
  end

  def test_should_take_the_verdict_of_the_needed_stage_that_finished_first
    assert_equal :over_budget, decide("fast", lint: "timed_out", build: "failed")
  end

  def test_should_ignore_a_stage_the_level_does_not_need
    assert_equal :undecided, decide("fast", lint: "completed", build: "completed", fast: "running", slow: "failed")
  end

  def test_should_need_only_lint_and_build_for_the_build_level
    assert_equal :passed, decide("build", lint: "completed", build: "completed")
  end

  def test_should_need_the_slow_suite_for_the_all_level
    assert_equal :undecided, decide("all", lint: "completed", build: "completed", fast: "completed")
  end

  def test_should_be_superseded_when_the_run_was_cancelled
    assert_equal :superseded, decide("fast", run_status: "cancelled", lint: "completed")
  end

  def test_should_keep_a_decided_verdict_when_the_run_was_cancelled_later
    assert_equal :passed, decide("build", run_status: "cancelled", lint: "completed", build: "completed")
  end

  private

  # Stages finish in the order given.
  def decide(need, run_status: "running", **stages)
    rows = stages.each_with_index.map { |(stage, status), i| { stage: stage.to_s, status: status, finished_order: i } }
    FunCi::Agent::Verdict.decide(run_status: run_status, stages: rows, need: need)
  end
end
