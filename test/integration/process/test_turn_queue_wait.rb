# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/process_deadline"
require "fun_ci/pipeline/turn_queue"

# A waiting slow suite blocks on a newer suite's ticket until that suite's
# process lets it go (TurnQueue::WAIT), across processes as SlowTurns uses it.
class TestTurnQueueWait < Minitest::Test
  include ProcessDeadline

  def setup
    @dir = Dir.mktmpdir
    @ticket = File.join(@dir, "newer.lock")
    @released = File.join(@dir, "released")
  end

  def teardown = FileUtils.remove_entry(@dir)

  def test_should_wait_until_the_suite_holding_the_ticket_lets_it_go
    holder, release = held_by_a_child
    release.close
    released = within_deadline { FunCi::Pipeline::TurnQueue::WAIT.call([@ticket]) && File.exist?(@released) }
    within_deadline { Process.wait(holder) }

    assert released
  end

  def test_should_not_wait_for_a_ticket_already_gone
    answer = within_deadline { FunCi::Pipeline::TurnQueue.wait_on(File.join(@dir, "gone.lock")) }

    assert_nil answer
  end

  private

  # A child holding the ticket, which notes that it lets go just before it
  # does, once `release` is closed; answers its pid and `release`.
  def held_by_a_child
    held_in, held_out = IO.pipe
    release_in, release = IO.pipe
    pid = fork { hold(held_out, release_in, release) }
    [held_out, release_in].each(&:close)
    within_deadline { held_in.read }
    [pid, release]
  end

  def hold(held, release_in, release)
    release.close
    ticket = File.new(@ticket, File::RDWR | File::CREAT, 0o644).tap { |file| file.flock(File::LOCK_EX) }
    held.close
    release_in.read
    File.write(@released, "")
    ticket.close
    exit!(0)
  end
end
