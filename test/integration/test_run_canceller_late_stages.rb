# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/persistence/active_runs"
require "fun_ci/pipeline/run_canceller"

# A run's forked slow suite can record its stage's process group, and let the
# stage start, after the canceller has looked at the run and before it kills
# the fork. Seen on Linux: the slow stage's script outlived the cancel in a
# process group of its own (AT-1.6, AT-1.12).
class TestRunCancellerLateStages < Minitest::Test
  include DatabaseTestSetup

  RUN = FunCi::Persistence::PipelineRun
  JOB = FunCi::Persistence::StageJob
  TRIGGER = 100
  SLOW_SUITE = 200

  def setup
    setup_test_db
    @run_id = RUN.create(@db, commit_hash: "abc1234", branch: "main", project_path: "/project")
    RUN.update_status(@db, @run_id, "running")
    RUN.store_trigger_pid(@db, @run_id, TRIGGER)
    RUN.store_pid(@db, @run_id, SLOW_SUITE)
    @slow = running_stage("slow")
    @sent = []
  end

  def teardown = teardown_test_db

  def test_should_stop_a_stage_that_started_between_the_look_and_the_kill
    looked = FunCi::Persistence::ActiveRuns.with_id(@db, @run_id).first
    canceller(started_as_the_slow_suite_dies: 500).cancel(@db, looked)

    assert_includes @sent, ["KILL", -500]
  end

  def test_should_signal_each_stage_group_once
    JOB.store_pid(@db, @slow, 500)
    looked = FunCi::Persistence::ActiveRuns.with_id(@db, @run_id).first
    canceller.cancel(@db, looked)

    assert_equal 1, @sent.count(["KILL", -500])
  end

  def test_should_not_look_again_at_a_run_it_did_not_stop
    JOB.store_pid(@db, @slow, 500)
    looked = FunCi::Persistence::ActiveRuns.with_id(@db, @run_id).first.with(stage_groups: [])
    FunCi::Pipeline::RunCanceller.new(killer: ->(*sent) { @sent << sent }, slot_held: ->(_lock) { false })
                                 .cancel(@db, looked.with(slot_lock: "/slot-0.lock"))

    assert_empty @sent
  end

  private

  def running_stage(stage)
    JOB.create(@db, pipeline_run_id: @run_id, stage: stage).tap { |job| JOB.update_status(@db, job, "running") }
  end

  # A killer that, as it kills the slow suite's process, has that process
  # record the group of the stage it has just started.
  def canceller(started_as_the_slow_suite_dies: nil)
    killer = lambda do |signal, pid|
      @sent << [signal, pid]
      JOB.store_pid(@db, @slow, started_as_the_slow_suite_dies) if pid == SLOW_SUITE && started_as_the_slow_suite_dies
    end
    FunCi::Pipeline::RunCanceller.new(killer: killer, slot_held: ->(_lock) { true })
  end
end
