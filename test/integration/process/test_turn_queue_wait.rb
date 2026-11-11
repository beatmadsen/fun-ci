# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/process_deadline"
require "fun_ci/pipeline/turn_queue"

# A waiting slow suite blocks on a newer suite's ticket until that suite's
# process lets it go (TurnQueue::WAIT), across processes as SlowTurns uses it.
# The test holds the ticket, a forked child waits on it, and ps says when the
# child has settled: blocked in a call (S), or finished (Z, or gone).
class TestTurnQueueWait < Minitest::Test
  include ProcessDeadline

  def setup
    @dir = Dir.mktmpdir
    @ticket = File.join(@dir, "newer.lock")
    @holding = File.new(@ticket, File::RDWR | File::CREAT, 0o644).tap { |file| file.flock(File::LOCK_EX) }
  end

  def teardown
    @holding.close unless @holding.closed?
    FileUtils.remove_entry(@dir)
  end

  def test_should_not_return_while_the_ticket_is_held
    waiter, said = waiting_child
    within_deadline { nil until settled?(waiter) }
    returned = said_done?(said)
    let_go_and_reap(waiter, said)

    refute returned
  end

  def test_should_return_once_the_ticket_is_let_go
    waiter, said = waiting_child
    @holding.close
    answer = within_deadline { said.gets }
    within_deadline { Process.wait(waiter) }

    assert_equal "done\n", answer
  end

  def test_should_not_wait_for_a_ticket_already_gone
    answer = within_deadline { FunCi::Pipeline::TurnQueue.wait_on(File.join(@dir, "gone.lock")) }

    assert_nil answer
  end

  private

  # A child waiting on the ticket, which says "done" once the wait returns;
  # answers its pid and what it says, once it has started.
  def waiting_child
    said, says = IO.pipe
    pid = fork { wait_and_say(said, says) }
    says.close
    within_deadline { said.gets }
    [pid, said]
  end

  # The child's copy of the test's lock goes first: it is the same open file,
  # so the child would otherwise wait on its own lock.
  def wait_and_say(said, says)
    [@holding, said].each(&:close)
    says.puts("waiting")
    says.flush
    FunCi::Pipeline::TurnQueue::WAIT.call([@ticket])
    says.puts("done")
    exit!(0)
  end

  def settled?(pid) = `ps -o stat= -p #{pid}`.strip.then { |state| state.empty? || state.start_with?("S", "Z") }
  def said_done?(said) = !said.wait_readable(0).nil?

  def let_go_and_reap(waiter, said)
    @holding.close
    within_deadline { said.read }
    within_deadline { Process.wait(waiter) }
  end
end
