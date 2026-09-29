# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/persistence/active_runs"

# A stage's end is recorded to the millisecond, as its start is, whichever
# way it ends: a stage recorded ending in the second it started, but with the
# milliseconds dropped, ends before it began.
class TestStageEndTimes < Minitest::Test
  include DatabaseTestSetup

  RUN = FunCi::Persistence::PipelineRun
  JOB = FunCi::Persistence::StageJob
  MILLISECONDS = /\.\d{3}Z\z/

  def setup = setup_test_db
  def teardown = teardown_test_db

  def test_should_record_a_cancelled_stage_s_end_to_the_millisecond
    job_id = running_stage
    FunCi::Persistence::ActiveRuns.cancelled(@db, FunCi::Persistence::ActiveRuns.with_id(@db, @run_id).first)

    assert_match MILLISECONDS, JOB.find(@db, job_id)[:completed_at]
  end

  def test_should_record_the_end_of_a_slow_suite_that_died_to_the_millisecond
    job_id = running_stage
    FunCi::Persistence::ActiveRuns.slow_suite_died(@db, job_id)

    assert_match MILLISECONDS, JOB.find(@db, job_id)[:completed_at]
  end

  private

  def running_stage
    @run_id = RUN.create(@db, commit_hash: "abc1234", branch: "main", project_path: "/project")
    RUN.update_status(@db, @run_id, "running")
    job_id = JOB.create(@db, pipeline_run_id: @run_id, stage: "slow")
    JOB.update_status(@db, job_id, "running")
    job_id
  end
end
