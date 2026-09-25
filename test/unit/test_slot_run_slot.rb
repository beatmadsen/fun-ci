# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/slot_run_kit"

# A pipeline lets go of its worktree slot when the last stage that uses it
# finishes, and not before.
class TestSlotRunSlot < Minitest::Test
  include SlotRunKit

  def test_should_let_go_of_the_slot_when_the_slow_suite_ran_before_the_fast_one_finished
    lock = Lock.new(false)
    slot_run(slot_with(lock), background_launcher: inline_launcher).run(config)

    assert_predicate lock, :closed?
  end

  def test_should_let_go_of_the_slot_when_phase_one_fails
    lock = Lock.new(false)
    slot_run(slot_with(lock), command_runner: scripted_runner({ "lint.sh" => failing("lint errors") })).run(config)

    assert_predicate lock, :closed?
  end

  def test_should_keep_the_slot_while_the_slow_suite_is_still_running
    lock = Lock.new(false)
    slot_run(slot_with(lock)).run(config)

    refute_predicate lock, :closed?
  end

  def test_should_let_go_of_the_slot_when_the_slow_suite_finishes_after_the_fast_one
    lock = Lock.new(false)
    slow = nil
    slot_run(slot_with(lock), background_launcher: ->(executor:, **) { slow = executor }).run(config)
    slow.call

    assert_predicate lock, :closed?
  end
end
