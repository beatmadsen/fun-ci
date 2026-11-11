# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/slot_run_kit"

# A run's slow suite waits until no older slow suite of its branch runs, and
# counts as started only from then (acceptance-tests.md, AT-9.19).
class TestSlotRunSlowTurn < Minitest::Test
  include SlotRunKit

  # A slot whose mark of a slow suite waiting its turn records being let go.
  class MarkedSlot < FunCi::Pipeline::Slot
    attr_reader :mark

    def waiting = (@mark = SlotRunKit::Lock.new(false))
  end

  # Turns that note whether the slot is marked waiting when the turn is asked for.
  class TurnsSeeingTheMark < FakeSlowTurns
    attr_reader :marked_while_waiting

    def initialize(slot)
      super()
      @slot = slot
    end

    def take(branch, &)
      @marked_while_waiting = !@slot.mark.closed?
      super
    end
  end

  # A recorder that notes whether the slot is still marked waiting as its slow suite starts.
  class RecorderSeeingTheMark < FakeRecorder
    attr_reader :marked_at_start

    def initialize(slot)
      super()
      @slot = slot
    end

    def started_in_turn?(job_id)
      @marked_at_start = !@slot.mark.closed?
      super
    end
  end

  # A recorder whose slow suite's run was recorded cancelled while it waited.
  class RefusedTurnRecorder < FakeRecorder
    def started_in_turn?(_job_id) = false
  end

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

  # A newer commit cancelled its run while it waited (StageJob.started_in_turn?).
  def test_should_not_run_the_slow_suite_when_its_turn_is_refused
    runner = scripted_runner
    recorder = RefusedTurnRecorder.new
    run_slow(FakeSlowTurns.new, recorder: recorder, command_runner: runner)

    refute runner.ran?("slow.sh")
  end

  # So the pool hands another branch's run a further slot meanwhile (WorktreePool).
  def test_should_mark_its_slot_waiting_while_it_waits_its_turn
    slot = MarkedSlot.new("/slot-0", Lock.new(false))
    turns = TurnsSeeingTheMark.new(slot)
    run_slow(turns, slot: slot)

    assert turns.marked_while_waiting
  end

  def test_should_unmark_its_slot_once_its_turn_comes
    slot = MarkedSlot.new("/slot-0", Lock.new(false))
    recorder = RecorderSeeingTheMark.new(slot)
    run_slow(FakeSlowTurns.new, slot: slot, recorder: recorder)

    refute recorder.marked_at_start
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

  def run_slow(turns, slot: slot_with(Lock.new(false)), recorder: FakeRecorder.new, **seams)
    slot_run(slot, recorder: recorder, background_launcher: inline_launcher(recorder), slow_turns: turns, **seams)
      .run(config)
  end

  def slow_calls(recorder)
    recorder.calls.select { |call| %i[schedule_stage stage_started].include?(call.first) && call[1] == "slow" }
  end
end
