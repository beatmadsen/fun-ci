# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/run_canceller"
require "fun_ci/evidence/process_table"

# Stopping every process of a run: its own Ruby processes first, so none of
# them can record the run as failed once its stages die, then each stage's
# process group. Only a run that is still alive is stopped: the pids a dead
# run recorded may belong to other processes by now.
class TestRunCanceller < Minitest::Test
  RUN = FunCi::Persistence::ActiveRun.new(id: 7, commit_hash: "abc1234", processes: [100, 200],
                                          stage_groups: [300, 400], slot_lock: "/slot-0.lock")
  ALL = [["KILL", 100], ["KILL", 200], ["KILL", -300], ["KILL", -400]].freeze

  def test_should_kill_the_run_s_processes_then_each_stage_s_process_group
    assert_equal ALL, signals_sent(RUN)
  end

  def test_should_carry_on_past_a_process_that_is_already_gone
    assert_equal ALL, signals_sent(RUN, gone: [100, -300])
  end

  def test_should_send_nothing_to_a_run_whose_slot_nobody_holds
    assert_empty signals_sent(RUN, alive: ->(_lock) { false })
  end

  def test_should_stop_a_run_still_waiting_for_a_slot
    assert_equal [["KILL", 100]], signals_sent(RUN.with(processes: [100], stage_groups: [], slot_lock: nil),
                                               alive: ->(_lock) { false })
  end

  # A stage's child that left the group, as Playwright's web server does, read before any kill.
  def test_should_kill_last_what_a_stage_started_that_left_its_group
    detached = [row(300, 1, 300), row(320, 300, 320)]

    assert_equal [*ALL, ["KILL", -320]], signals_sent(RUN, table: -> { detached })
  end

  def test_should_read_the_process_table_before_it_kills_anything
    order = []
    canceller = FunCi::Pipeline::RunCanceller.new(killer: ->(*) { order << :kill }, slot_held: ->(_lock) { true },
                                                  process_table: -> { (order << :read) && [] })
    canceller.stop(RUN)

    assert_equal :read, order.first
  end

  def test_should_never_signal_its_own_process
    assert_equal [["KILL", 200]], signals_sent(RUN.with(processes: [Process.pid, 200], stage_groups: []))
  end

  private

  def signals_sent(run, gone: [], alive: ->(_lock) { true }, table: -> { [] })
    sent = []
    killer = lambda do |signal, pid|
      sent << [signal, pid]
      raise Errno::ESRCH if gone.include?(pid)
    end
    FunCi::Pipeline::RunCanceller.new(killer: killer, slot_held: alive, process_table: table).stop(run)
    sent
  end

  def row(pid, ppid, pgid)
    FunCi::Evidence::ProcessTable::Row.new(pid: pid, ppid: ppid, pgid: pgid, seconds: 1, command: "x")
  end
end
