# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/slot_run_kit"

# While a run's slow suite waits its branch's turn, its slot is marked waiting,
# so the pool hands another branch's run a further slot (WaitingSlots); the
# mark goes once the turn comes, or the wait ends otherwise.
class TestSlotRunWaitingMark < Minitest::Test
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

    def take(branch, ticket, &)
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

  # As when the wait for it ends some other way than with the turn.
  def test_should_unmark_its_slot_when_its_turn_never_comes
    slot = MarkedSlot.new("/slot-0", Lock.new(false))
    run_slow(FakeSlowTurns.new(given: false), slot: slot)

    assert_predicate slot.mark, :closed?
  end

  private

  def run_slow(turns, slot: slot_with(Lock.new(false)), recorder: FakeRecorder.new, **seams)
    slot_run(slot, recorder: recorder, background_launcher: inline_launcher(recorder), slow_turns: turns, **seams)
      .run(config)
  end
end
