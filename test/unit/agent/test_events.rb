# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/agent/events"

class TestEvents < Minitest::Test
  EVENTS = FunCi::Agent::Events
  RUN = EVENTS::RunState

  STARTED = "2026-10-21T15:00:00Z"
  CHANGED = "2026-10-21T15:04:10Z"
  TIMES = EVENTS::RunTimes.new(started: STARTED, changed: CHANGED, checked: nil)

  def test_should_start_a_run_it_has_not_seen
    assert_equal [{ event: "run_started", commit: "abc1234", branch: "main", at: STARTED }],
                 EVENTS.between({}, snapshot(run_state))
  end

  def test_should_finish_each_stage_that_finished_since_in_the_order_they_finished
    before = snapshot(run_state(finished: [stage("lint", "passed")]))
    after = snapshot(run_state(finished: [stage("lint", "passed"), stage("build", "failed", 2.5),
                                          stage("fast", "passed")]))

    assert_equal([%w[build failed], %w[fast passed]],
                 EVENTS.between(before, after).map { |event| event.values_at(:stage, :state) })
  end

  def test_should_say_how_long_a_stage_took_and_when_it_finished
    after = snapshot(run_state(finished: [stage("build", "failed", 2.5)]))

    assert_equal({ event: "stage_finished", commit: "abc1234", branch: "main", stage: "build", state: "failed",
                   seconds: 2.5, at: "2026-10-21T15:01:00Z" }, EVENTS.between(snapshot(run_state), after).first)
  end

  def test_should_finish_a_run_that_passed
    assert_equal [{ event: "run_finished", commit: "abc1234", branch: "main", state: "passed", at: CHANGED }],
                 EVENTS.between(snapshot(run_state), snapshot(run_state(status: "completed")))
  end

  def test_should_finish_a_run_that_failed
    assert_equal "failed", EVENTS.between(snapshot(run_state), snapshot(run_state(status: "failed"))).first[:state]
  end

  def test_should_supersede_a_run_that_was_cancelled_naming_the_newer_commit
    assert_equal [{ event: "run_superseded", commit: "abc1234", branch: "main", by_commit: "bcd2345", at: CHANGED }],
                 EVENTS.between(snapshot(run_state), snapshot(run_state(status: "cancelled", superseded_by: "bcd2345")))
  end

  def test_should_say_nothing_about_a_run_that_has_not_changed
    assert_empty EVENTS.between(snapshot(run_state(status: "failed")), snapshot(run_state(status: "failed")))
  end

  def test_should_tell_runs_apart_in_the_order_they_started
    after = { 2 => run_state(id: 2, sha: "bcd2345"), 1 => run_state(id: 1) }

    assert_equal(%w[abc1234 bcd2345], EVENTS.between({}, after).map { |event| event[:commit] })
  end

  def test_should_count_failed_and_over_budget_stages_and_superseded_runs_as_failures
    failures = [{ event: "stage_finished", state: "failed" }, { event: "stage_finished", state: "over_budget" },
                { event: "run_superseded" }]
    others = [{ event: "stage_finished", state: "passed" }, { event: "run_started" }, { event: "run_finished" }]

    assert_equal(failures, (failures + others).select { |event| EVENTS.failure?(event) })
  end

  private

  def run_state(id: 1, sha: "abc1234", **changes)
    RUN.new(id: id, sha: sha, branch: "main", status: "running", finished: [], superseded_by: nil, times: TIMES)
       .with(**changes)
  end

  def stage(name, state, seconds = 1.0)
    { stage: name, state: state, seconds: seconds, at: "2026-10-21T15:01:00Z" }
  end

  def snapshot(state) = { state.id => state }
end
