# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/persistence/stage_job"
require "fun_ci/persistence/project_runs"

# The end of a failed stage's output is kept with the stage, and dropped once
# its run is older than the project's newest ones (acceptance-tests.md, AT-9.5).
class TestStageOutput < Minitest::Test
  include DatabaseTestSetup

  JOB = FunCi::Persistence::StageJob

  def setup = setup_test_db
  def teardown = teardown_test_db

  def test_should_keep_the_output_with_the_stage
    job_id = job_of(new_run)
    JOB.keep_output(@db, job_id, "line 1\nline 2\n")

    assert_equal "line 1\nline 2\n", JOB.find(@db, job_id)[:output_tail]
  end

  def test_should_drop_the_output_of_runs_older_than_the_newest_kept
    old_job = job_of(new_run)
    2.times { JOB.keep_output(@db, job_of(new_run), "newer\n") }
    JOB.keep_output(@db, old_job, "old\n")

    FunCi::Persistence::ProjectRuns.new(@db, "/project").forget_output(keep: 2)

    assert_nil JOB.find(@db, old_job)[:output_tail]
  end

  def test_should_keep_the_output_of_the_newest_runs
    job = job_of(new_run)
    JOB.keep_output(@db, job, "newest\n")

    FunCi::Persistence::ProjectRuns.new(@db, "/project").forget_output(keep: 1)

    assert_equal "newest\n", JOB.find(@db, job)[:output_tail]
  end

  def test_should_leave_another_project_s_output_alone
    job = job_of(new_run(project: "/elsewhere"))
    JOB.keep_output(@db, job, "theirs\n")
    new_run

    FunCi::Persistence::ProjectRuns.new(@db, "/project").forget_output(keep: 1)

    assert_equal "theirs\n", JOB.find(@db, job)[:output_tail]
  end

  private

  def new_run(project: "/project")
    FunCi::Persistence::PipelineRun.create(@db, commit_hash: "abc1234", branch: "main", project_path: project)
  end

  def job_of(run_id) = JOB.create(@db, pipeline_run_id: run_id, stage: "fast")
end
