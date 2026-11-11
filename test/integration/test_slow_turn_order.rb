# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/slow_turns"
require "fun_ci/pipeline/slot_lock"

# Of a branch's slow suites waiting their turn, the one whose commit arrived
# last goes next (acceptance-tests.md, AT-9.19, AT-9.20). Each holds a ticket
# while it waits and runs; `wait` stands in for blocking until a newer
# ticket's suite is done, and is the test's say in when that happens.
class TestSlowTurnOrder < Minitest::Test
  TICKET = FunCi::Pipeline::TurnTicket

  def setup
    @root = File.join(Dir.mktmpdir, "slow")
    @held = []
    @log = []
  end

  def teardown = @held.each(&:close)

  def test_should_let_a_newer_waiting_suite_go_first
    newer = hold_ticket(TICKET.new(place: 5, id: 9))
    turns(wait: finishing(newer)).take("main", TICKET.new(place: 3, id: 8)) do
      @log << :older_ran
    end

    assert_equal %i[newer_done older_ran], @log
  end

  # The wait ends only once the ticket's holder lets go, so one that still
  # seems held after it is no live suite's.
  def test_should_wait_for_each_newer_suite_once
    hold_ticket(TICKET.new(place: 5, id: 9))
    turns(wait: never_freeing).take("main", TICKET.new(place: 3, id: 8)) { nil }

    assert_equal [TICKET.new(place: 5, id: 9).name], @log
  end

  def test_should_not_wait_for_an_older_waiting_suite
    hold_ticket(TICKET.new(place: 3, id: 8))
    ran = turns.take("main", TICKET.new(place: 5, id: 9)) { :ran }

    assert_equal :ran, ran
  end

  def test_should_count_a_later_run_of_the_same_commit_as_newer
    newer = hold_ticket(TICKET.new(place: 3, id: 9))
    turns(wait: finishing(newer)).take("main", TICKET.new(place: 3, id: 8)) do
      @log << :older_ran
    end

    assert_equal %i[newer_done older_ran], @log
  end

  def test_should_not_wait_for_a_newer_suite_of_another_branch
    hold_ticket(TICKET.new(place: 5, id: 9), branch: "feature/x")
    ran = turns.take("main", TICKET.new(place: 3, id: 8)) { :ran }

    assert_equal :ran, ran
  end

  def test_should_not_wait_for_a_ticket_left_by_a_suite_that_died
    hold_ticket(TICKET.new(place: 5, id: 9)).close
    ran = turns.take("main", TICKET.new(place: 3, id: 8)) { :ran }

    assert_equal :ran, ran
  end

  def test_should_remove_a_ticket_left_by_a_suite_that_died
    hold_ticket(TICKET.new(place: 5, id: 9)).close
    turns.take("main", TICKET.new(place: 3, id: 8)) { nil }

    refute_path_exists turns.ticket_path("main", TICKET.new(place: 5, id: 9))
  end

  def test_should_hold_its_ticket_while_its_suite_runs
    ticket = TICKET.new(place: 3, id: 8)
    held = turns.take("main", ticket) { FunCi::Pipeline::SlotLock.held?(turns.ticket_path("main", ticket)) }

    assert held
  end

  def test_should_leave_no_ticket_behind_once_its_turn_is_over
    ticket = TICKET.new(place: 3, id: 8)
    turns.take("main", ticket) { nil }

    refute_path_exists turns.ticket_path("main", ticket)
  end

  private

  def turns(wait: ->(_path) { flunk "waited with no newer suite" })
    FunCi::Pipeline::SlowTurns.new(@root, wait: wait)
  end

  # A wait that leaves the ticket held, and fails the test when asked again,
  # so a loop that waits on without end stops at once.
  def never_freeing = ->(path) { @log.empty? ? @log << File.basename(path) : flunk("waited again on #{path}") }

  # A wait that ends as the newer suite finishes.
  def finishing(newer) = ->(_path) { finish(newer) }

  def finish(newer)
    @log << :newer_done
    newer.close
  end

  # A ticket as a live slow suite holds it.
  def hold_ticket(ticket, branch: "main")
    path = turns.ticket_path(branch, ticket)
    FileUtils.mkdir_p(File.dirname(path))
    File.new(path, File::RDWR | File::CREAT, 0o644).tap { |file| file.flock(File::LOCK_EX) }.tap { |file| @held << file }
  end
end
