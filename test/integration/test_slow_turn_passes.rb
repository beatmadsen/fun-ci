# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/slow_turn_kit"
require "fun_ci/pipeline/slot_lock"

# How SlowTurns lets newer suites go first, in passes: each waits for the
# newer suites not yet waited for, takes the turn and looks again, letting it
# go if another queued meanwhile. `wait` is called once a pass, with the
# tickets it waits for, and takes the test's next step.
class TestSlowTurnPasses < Minitest::Test
  include SlowTurnKit

  def setup
    @root = File.join(Dir.mktmpdir, "slow")
    @held = []
    @log = []
  end

  def teardown = @held.each(&:close)

  # The wait ends only once the ticket's holder lets go, so one that still
  # seems held after it is no live suite's.
  def test_should_wait_for_each_newer_suite_once
    hold_ticket(TICKET.new(place: 5, id: 9))
    turns(wait: scripted([-> {}])).take("main", TICKET.new(place: 3, id: 8)) { nil }

    assert_equal [[TICKET.new(place: 5, id: 9).name]], @log
  end

  # A newer suite queues while it waits for the first; the first is not waited for again.
  def test_should_wait_only_for_newer_suites_it_has_not_waited_for
    hold_ticket(TICKET.new(place: 5, id: 9))
    turns(wait: scripted([-> { hold_ticket(TICKET.new(place: 7, id: 10)) }, -> {}]))
      .take("main", TICKET.new(place: 3, id: 8)) { nil }

    assert_equal [[TICKET.new(place: 5, id: 9).name], [TICKET.new(place: 7, id: 10).name]], @log
  end

  # The newer suite it waits for has to take the turn itself.
  def test_should_let_the_turn_go_while_it_waits_for_a_suite_that_queued_as_it_took_it
    hold_ticket(TICKET.new(place: 5, id: 9))
    held = []
    turns(wait: scripted([-> { hold_ticket(TICKET.new(place: 7, id: 10)) }, -> { held << turn_held? }]))
      .take("main", TICKET.new(place: 3, id: 8)) { nil }

    assert_equal [false], held
  end

  # A mutant that never lets the passes end is stopped there too.
  def test_should_take_its_turn_once_it_has_let_as_many_newer_suites_go_as_it_allows
    hold_ticket(TICKET.new(place: 5, id: 1))
    ran = turns(wait: queueing_another).take("main", TICKET.new(place: 3, id: 0)) { :ran }

    assert_equal :ran, ran
  end

  private

  def turn_held? = FunCi::Pipeline::SlotLock.held?(turns.lock_path("main"))

  # A wait that leaves each ticket held, keeps their names and takes the next
  # step, failing the test once the steps run out.
  def scripted(steps) = ->(paths) { take_step(steps, paths) }

  def take_step(steps, paths)
    @log << paths.map { |path| File.basename(path) }
    flunk "a pass past the script, waiting for #{paths}" if steps.empty?
    steps.shift.call
  end

  # A wait after which a further newer suite has queued, failing the test
  # once it has been asked more often than SlowTurns allows.
  def queueing_another
    lambda do |_paths|
      flunk "waited past #{ROUNDS} rounds" if @log.size >= ROUNDS
      @log << hold_ticket(TICKET.new(place: 6 + @log.size, id: 1))
    end
  end
end
