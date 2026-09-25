# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/console/stage_events"

# AT-2.3: a stage's change between two polls becomes an event the renderer
# animates; Ruby decides that it happened, the renderer how it looks.
class TestStageEvents < Minitest::Test
  def setup
    @events = FunCi::Console::StageEvents.new
  end

  def poll(fast) = @events.since_last([{ id: 3, stages: [{ stage: "fast", status: fast }] }])

  def test_should_send_nothing_on_the_first_poll
    assert_empty poll("failed")
  end

  def test_should_send_stage_failed_when_a_stage_fails
    poll("running")

    assert_equal [{ t: "event", name: "stage_failed", run_id: 3, stage: "fast" }], poll("failed")
  end

  def test_should_send_stage_failed_when_a_stage_times_out
    poll("running")

    assert_equal(["stage_failed"], poll("timed_out").map { _1[:name] })
  end

  def test_should_send_stage_passed_when_a_stage_completes
    poll("running")

    assert_equal(["stage_passed"], poll("completed").map { _1[:name] })
  end

  def test_should_send_nothing_when_a_stage_starts_running
    poll("scheduled")

    assert_empty poll("running")
  end

  def test_should_send_nothing_when_a_stage_is_cancelled
    poll("running")

    assert_empty poll("cancelled")
  end

  def test_should_send_nothing_when_no_stage_changed
    poll("running")

    assert_empty poll("running")
  end

  def test_should_compare_with_the_poll_just_before
    poll("running")
    poll("failed")

    assert_empty poll("failed")
  end

  def test_should_send_nothing_for_a_run_the_last_poll_did_not_see
    poll("running")

    assert_empty @events.since_last([{ id: 4, stages: [{ stage: "fast", status: "failed" }] }])
  end
end
