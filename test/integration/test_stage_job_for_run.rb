# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"
require "fun_ci/persistence/stage_job"
require "tmpdir"

# A run's stage jobs, as the console shows them.
class TestStageJobForRun < Minitest::Test
  include DatabaseTestSetup

  def setup
    setup_test_db
    @run_id = FunCi::Persistence::PipelineRun.create(@db, commit_hash: "abc123", branch: "main")
    other_run = FunCi::Persistence::PipelineRun.create(@db, commit_hash: "def456", branch: "main")
    %w[lint build].each { |stage| FunCi::Persistence::StageJob.create(@db, pipeline_run_id: @run_id, stage: stage) }
    FunCi::Persistence::StageJob.create(@db, pipeline_run_id: other_run, stage: "fast")
  end

  def teardown = teardown_test_db

  def test_should_list_only_the_run_s_jobs_in_the_order_they_were_created
    assert_equal(%w[lint build], FunCi::Persistence::StageJob.for_run(@db, @run_id).map { |job| job[:stage] })
  end

  def test_should_give_each_job_its_status
    assert_equal(%w[scheduled scheduled], FunCi::Persistence::StageJob.for_run(@db, @run_id).map { |job| job[:status] })
  end
end
