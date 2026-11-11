# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/slot_run_kit"

# A run's slow suite waits until no older slow suite of its branch runs, and
# counts as started only from then (acceptance-tests.md, AT-9.19).
class TestSlotRunSlowTurn < Minitest::Test
  include SlotRunKit

  def test_should_wait_for_its_branch_s_turn
    turns = FakeSlowTurns.new
    run_slow(turns)

    assert_equal ["main"], turns.asked
  end

  def test_should_not_run_the_slow_suite_before_its_turn
    runner = scripted_runner
    run_slow(FakeSlowTurns.new(given: false), command_runner: runner)

    refute runner.ran?("slow.sh")
  end

  def test_should_run_the_slow_suite_once_it_has_its_turn
    runner = scripted_runner
    run_slow(FakeSlowTurns.new, command_runner: runner)

    assert runner.ran?("slow.sh")
  end

  def test_should_record_the_slow_suite_waiting_while_it_has_no_turn
    recorder = FakeRecorder.new
    run_slow(FakeSlowTurns.new(given: false), recorder: recorder)

    assert_equal [[:schedule_stage, "slow"]], slow_calls(recorder)
  end

  def test_should_record_the_slow_suite_started_once_it_has_its_turn
    recorder = FakeRecorder.new
    run_slow(FakeSlowTurns.new, recorder: recorder)

    assert_equal [[:schedule_stage, "slow"], [:stage_started, "slow"]], slow_calls(recorder)
  end

  private

  def run_slow(turns, recorder: FakeRecorder.new, **seams)
    slot_run(slot_with(Lock.new(false)), recorder: recorder, background_launcher: inline_launcher(recorder),
                                         slow_turns: turns, **seams).run(config)
  end

  def slow_calls(recorder)
    recorder.calls.select { |call| %i[schedule_stage stage_started].include?(call.first) && call[1] == "slow" }
  end
end
