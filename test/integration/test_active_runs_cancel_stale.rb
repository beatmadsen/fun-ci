# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/persistence/active_runs"

# Which runs a new commit's run cancels on its branch, recorded cancelled as
# they are picked (ActiveRuns.cancel_stale).
class TestActiveRunsCancelStale < Minitest::Test
  include DatabaseTestSetup

  RUN = FunCi::Persistence::PipelineRun
  JOB = FunCi::Persistence::StageJob
  BRANCH = FunCi::Persistence::Branch
  PROJECT = "/project"

  def setup = setup_test_db
  def teardown = teardown_test_db

  def test_should_leave_out_runs_on_other_branches
    running_run

    assert_empty cancellable(branch: BRANCH.new(project: PROJECT, name: "feature"))
  end

  def test_should_leave_out_runs_of_other_projects_on_a_branch_of_the_same_name
    running_run

    assert_empty cancellable(branch: BRANCH.new(project: "/other-project", name: "main"))
  end

  # Runs kept before their project was (no project_path) belong to no branch a commit names.
  def test_should_cancel_no_run_for_a_branch_whose_project_is_unknown
    RUN.update_status(@db, RUN.create(@db, commit_hash: "abc1234", branch: "main"), "running")

    assert_empty cancellable(branch: BRANCH.new(project: nil, name: "main"))
  end

  def test_should_record_cancelled_the_runs_it_picks_to_cancel
    run_id = running_run
    cancellable

    assert_equal "cancelled", RUN.find(@db, run_id)[:status]
  end

  def test_should_leave_out_a_run_whose_slow_suite_is_running
    stage(running_run, "slow", 400, "running")

    assert_empty cancellable
  end

  def test_should_leave_the_new_commit_s_own_run_out_of_those_to_cancel
    running_run

    assert_empty cancellable(new_commit: "abc1234")
  end

  def test_should_leave_a_run_waited_on_since_the_cutoff_out_of_those_to_cancel
    RUN.mark_waited(@db, running_run, "2026-09-27T12:00:05Z")

    assert_empty cancellable(waited_before: "2026-09-27T12:00:00Z")
  end

  def test_should_count_a_run_last_waited_on_before_the_cutoff_among_those_to_cancel
    RUN.mark_waited(@db, running_run, "2026-09-27T11:59:00Z")

    assert_equal 1, cancellable(waited_before: "2026-09-27T12:00:00Z").size
  end

  private

  def cancellable(branch: BRANCH.new(project: PROJECT, name: "main"), new_commit: "fff0000",
                  waited_before: "2026-09-27T12:00:00Z")
    FunCi::Persistence::ActiveRuns.cancel_stale(@db, branch, new_commit: new_commit, waited_before: waited_before)
  end

  # Lint finished; fast is running in process group 300.
  def running_run
    run_id = RUN.create(@db, commit_hash: "abc1234", branch: "main", project_path: PROJECT)
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
