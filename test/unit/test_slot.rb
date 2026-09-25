# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/slot"

class TestSlot < Minitest::Test
  class Lock
    def closed? = @closed == true
    def close = (@closed = true)
  end

  def test_releasing_the_only_hold_frees_the_slot
    lock = Lock.new
    FunCi::Pipeline::Slot.new("/slot-0", lock).release

    assert_predicate lock, :closed?
  end

  def test_a_shared_slot_stays_held_until_both_holders_release_it
    lock = Lock.new
    FunCi::Pipeline::Slot.new("/slot-0", lock).share.release

    refute_predicate lock, :closed?
  end

  def test_a_shared_slot_frees_when_the_second_holder_releases_it
    lock = Lock.new
    slot = FunCi::Pipeline::Slot.new("/slot-0", lock).share
    2.times { slot.release }

    assert_predicate lock, :closed?
  end
end
