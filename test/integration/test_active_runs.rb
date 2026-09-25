# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/persistence/active_runs"

# The runs on a branch that have not finished, with the processes that would
# have to be stopped to cancel them, and recording a run as cancelled.
class TestActiveRuns < Minitest::Test
  include DatabaseTestSetup

  RUN = FunCi::Persistence::PipelineRun
  JOB = FunCi::Persistence::StageJob

  def setup = setup_test_db
  def teardown = teardown_test_db

  def test_should_know_the_trigger_and_slow_suite_processes_of_a_running_run
    running_run

    assert_equal [100, 200], active.first.processes
  end

  def test_should_know_the_process_group_of_each_stage_still_running
    running_run

    assert_equal [300], active.first.stage_groups
  end

  def test_should_know_the_lock_of_the_slot_the_run_holds
    RUN.store_slot_lock(@db, running_run, "/worktrees/slot-0.lock")

    assert_equal "/worktrees/slot-0.lock", active.first.slot_lock
  end

  def test_should_count_a_run_waiting_for_a_slot_as_active
    RUN.store_trigger_pid(@db, RUN.create(@db, commit_hash: "abc1234", branch: "main"), 100)

    assert_equal [[100]], active.map(&:processes)
  end

  def test_should_leave_out_finished_runs
    run_id = running_run
    RUN.update_status(@db, run_id, "failed")

    assert_empty active
  end

  def test_should_leave_out_runs_on_other_branches
    running_run

    assert_empty FunCi::Persistence::ActiveRuns.on_branch(@db, "feature")
  end

  def test_should_record_the_run_cancelled
    run_id = running_run
    FunCi::Persistence::ActiveRuns.cancelled(@db, active.first)

    assert_equal "cancelled", RUN.find(@db, run_id)[:status]
  end

  def test_should_record_its_unfinished_stages_cancelled_and_leave_finished_ones
    run_id = running_run
    FunCi::Persistence::ActiveRuns.cancelled(@db, active.first)

    assert_equal %w[completed cancelled], job_statuses(run_id)
  end

  private

  def active = FunCi::Persistence::ActiveRuns.on_branch(@db, "main")

  def job_statuses(run_id)
    @db.execute("SELECT status FROM stage_jobs WHERE pipeline_run_id = ? ORDER BY id", [run_id]).flatten
  end

  # Lint finished; fast is running in process group 300.
  def running_run
    run_id = RUN.create(@db, commit_hash: "abc1234", branch: "main")
    RUN.update_status(@db, run_id, "running")
    RUN.store_trigger_pid(@db, run_id, 100)
    RUN.store_pid(@db, run_id, 200)
    stage(run_id, "lint", 250, "running", "completed")
    stage(run_id, "fast", 300, "running")
    run_id
  end

  def stage(run_id, name, pid, *statuses)
    job_id = JOB.create(@db, pipeline_run_id: run_id, stage: name)
    JOB.store_pid(@db, job_id, pid)
    statuses.each { |status| JOB.update_status(@db, job_id, status) }
  end
end
