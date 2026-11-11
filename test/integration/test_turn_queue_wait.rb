# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/turn_queue"
require "fun_ci/pipeline/slot_lock"

# A waiting slow suite's wait on a newer suite's ticket (TurnQueue.wait_on),
# against real lock files. That the wait blocks while the ticket is held is
# no test's: telling a blocked call from one not yet made needs the clock or
# the OS's view of the process, and neither gives the same verdict every run.
class TestTurnQueueWait < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
  end

  def teardown = FileUtils.remove_entry(@dir)

  # A lock the wait kept would make the ticket seem a live suite's to every
  # suite that looks after it. As when the newer suite was done before the
  # wait began, but its ticket not yet removed.
  def test_should_leave_the_ticket_free_once_its_wait_returns
    ticket = File.join(@dir, "newer.lock")
    File.new(ticket, File::RDWR | File::CREAT, 0o644).tap { |file| file.flock(File::LOCK_EX) }.close
    FunCi::Pipeline::TurnQueue.wait_on(ticket)

    refute FunCi::Pipeline::SlotLock.held?(ticket)
  end

  def test_should_return_for_a_ticket_already_gone
    assert_nil FunCi::Pipeline::TurnQueue.wait_on(File.join(@dir, "gone.lock"))
  end
end
