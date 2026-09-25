# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/run_canceller"

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

  def test_should_never_signal_its_own_process
    assert_equal [["KILL", 200]], signals_sent(RUN.with(processes: [Process.pid, 200], stage_groups: []))
  end

  private

  def signals_sent(run, gone: [], alive: ->(_lock) { true })
    sent = []
    killer = lambda do |signal, pid|
      sent << [signal, pid]
      raise Errno::ESRCH if gone.include?(pid)
    end
    FunCi::Pipeline::RunCanceller.new(killer: killer, slot_held: alive).stop(run)
    sent
  end
end
