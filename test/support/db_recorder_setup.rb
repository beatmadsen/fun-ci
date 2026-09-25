# frozen_string_literal: true

require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_recorder"
require "fun_ci/persistence/pipeline_run"
require "fun_ci/persistence/stage_job"

module DbRecorderTestSetup
  include DatabaseTestSetup

  def setup
    setup_test_db
    @recorder = FunCi::Persistence::DbRecorder.new(@db)
  end

  def teardown
    teardown_test_db
  end

  def create_run
    @recorder.create_run(commit_hash: "abc1234", branch: "main")
  end

  def run_status
    FunCi::Persistence::PipelineRun.find_by_commit(@db, "abc1234").first[:status]
  end

  def job(job_id)
    FunCi::Persistence::StageJob.find(@db, job_id)
  end
end
