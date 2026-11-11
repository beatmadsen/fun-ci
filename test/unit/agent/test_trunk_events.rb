# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/agent/events"

# Checks against the trunk as events (design.md, The trunk).
class TestTrunkEvents < Minitest::Test
  EVENTS = FunCi::Agent::Events
  CONFLICTS = { state: "conflicts", sha: "fff" }.freeze

  CHECKED = "2026-10-21T15:00:30Z"
  TIMES = EVENTS::RunTimes.new(started: "2026-10-21T15:00:00Z", changed: "2026-10-21T15:00:00Z", checked: CHECKED)

  def test_should_report_a_check_recorded_since_with_when_it_was_made
    assert_equal [{ event: "trunk_checked", commit: "abc1234", branch: "main", trunk: CONFLICTS, at: CHECKED }],
                 EVENTS.between(snapshot(run_state), snapshot(run_state(trunk: CONFLICTS)))
  end

  def test_should_report_a_check_against_another_tip
    moved = { state: "clean", sha: "aaa" }

    assert_equal([moved], EVENTS.between(snapshot(run_state(trunk: CONFLICTS)), snapshot(run_state(trunk: moved)))
                                .map { |event| event[:trunk] })
  end

  def test_should_report_nothing_for_a_check_seen_before
    assert_empty EVENTS.between(snapshot(run_state(trunk: CONFLICTS)), snapshot(run_state(trunk: CONFLICTS)))
  end

  def test_should_not_count_a_check_among_the_failures
    refute EVENTS.failure?({ event: "trunk_checked", trunk: CONFLICTS })
  end

  private

  def run_state(**changes)
    EVENTS::RunState.new(id: 1, sha: "abc1234", branch: "main", status: "running", finished: [], superseded_by: nil,
                         times: TIMES).with(**changes)
  end

  def snapshot(state) = { state.id => state }
end
