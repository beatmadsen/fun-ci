# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/console/milestone_events"

# AT-7.2: each milestone a run reaches between two polls becomes one event,
# in the order it was reached.
class TestMilestoneEvents < Minitest::Test
  def setup
    @events = FunCi::Console::MilestoneEvents.new
  end

  def test_should_send_nothing_on_the_first_poll
    assert_empty names(a_run(lint: done))
  end

  def test_should_send_lint_passed_when_lint_passes
    names(a_run(lint: is("running")))

    assert_equal [{ t: "event", name: "lint_passed", run_id: 3 }], @events.since_last([a_run(lint: done)])
  end

  def test_should_order_lint_and_build_by_the_order_they_finished_in
    names(a_run)

    assert_equal %w[build_passed lint_passed], names(a_run(lint: done(2), build: done(1)))
  end

  def test_should_put_lint_first_for_stages_recorded_without_a_finishing_order
    names(a_run)

    assert_equal %w[lint_passed build_passed], names(a_run(build: is("completed"), lint: is("completed")))
  end

  def test_should_send_every_milestone_skipped_between_polls_in_order
    names(a_run)

    assert_equal %w[lint_passed build_passed fast_passed run_passed],
                 names(a_run(status: "completed", lint: done(1), build: done(2), fast: done(4), slow: done(3)))
  end

  def test_should_not_count_the_slow_suite_passing_before_the_fast_suite_as_a_milestone
    names(a_run(lint: done, build: done))

    assert_empty names(a_run(lint: done, build: done, slow: done))
  end

  def test_should_send_milestones_reached_before_a_failure_ahead_of_run_failed
    names(a_run)

    assert_equal %w[lint_passed run_failed], names(a_run(status: "failed", lint: done, build: is("failed")))
  end

  def test_should_send_run_failed_once_however_many_stages_fail
    names(a_run(status: "failed", build: is("failed")))

    assert_empty names(a_run(status: "failed", build: is("failed"), lint: is("failed")))
  end

  def test_should_send_nothing_more_once_a_run_has_failed
    names(a_run(status: "failed", lint: is("failed")))

    assert_empty names(a_run(status: "failed", lint: is("failed"), build: done))
  end

  def test_should_send_the_milestones_of_a_run_first_seen_after_the_first_poll
    @events.since_last([])

    assert_equal %w[lint_passed], names(a_run(lint: done))
  end

  def test_should_send_nothing_for_a_cancelled_run
    names(a_run(lint: is("running")))

    assert_empty names(a_run(status: "cancelled", lint: done))
  end

  private

  def names(*runs) = @events.since_last(runs).map { |event| event[:name] }
  def done(order = 1) = { status: "completed", finished_order: order }

  def is(status) = { status: status }

  def a_run(status: "running", **stages)
    { id: 3, status: status, stages: stages.map { |name, stage| { stage: name.to_s, **stage } } }
  end
end
