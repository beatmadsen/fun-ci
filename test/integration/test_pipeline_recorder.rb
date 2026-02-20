# frozen_string_literal: true

require_relative "../test_helper"
require "tmpdir"
require "fun_ci/database"
require "fun_ci/pipeline_recorder"
require "fun_ci/pipeline_run"
require "fun_ci/stage_job"

class TestDbRecorderStartStage < Minitest::Test
  include DatabaseTestSetup

  def setup
    setup_test_db
    @recorder = FunCi::DbRecorder.new(@db)
  end

  def teardown
    teardown_test_db
  end

  def test_should_transition_pipeline_run_to_running_when_first_stage_starts
    # Given a recorder with a scheduled pipeline run
    @recorder.create_run(commit_hash: "abc1234", branch: "main")
    run_before = FunCi::PipelineRun.find_by_commit(@db, "abc1234").first
    assert_equal "scheduled", run_before[:status], "Precondition: run should be scheduled"
    # When the first stage starts
    @recorder.start_stage("build")
    # Then the pipeline run should transition to running
    run_after = FunCi::PipelineRun.find_by_commit(@db, "abc1234").first
    assert_equal "running", run_after[:status],
      "Pipeline run should transition to running when a stage starts"
  end

  def test_should_keep_pipeline_run_running_when_second_stage_starts
    # Given a recorder whose first stage has already started (run is "running")
    @recorder.create_run(commit_hash: "abc1234", branch: "main")
    @recorder.start_stage("build")
    # When a second stage starts
    @recorder.start_stage("fast")
    # Then the pipeline run should still be running
    run = FunCi::PipelineRun.find_by_commit(@db, "abc1234").first
    assert_equal "running", run[:status],
      "Pipeline run should remain running when additional stages start"
  end

  def test_should_create_stage_job_with_running_status
    # Given a recorder with a pipeline run
    @recorder.create_run(commit_hash: "abc1234", branch: "main")
    # When a stage starts
    job_id = @recorder.start_stage("build")
    # Then a stage_job should exist with status "running"
    job = FunCi::StageJob.find(@db, job_id)
    assert_equal "running", job[:status],
      "Stage job should be running after start_stage"
    assert_equal "build", job[:stage],
      "Stage job should record the stage name"
  end

  def test_should_return_nil_when_no_pipeline_run_exists
    # Given a recorder with no pipeline run created
    # When start_stage is called
    result = @recorder.start_stage("build")
    # Then it should return nil (no-op guard)
    assert_nil result, "Should return nil when no pipeline run exists"
  end
end

class TestDbRecorderEndStage < Minitest::Test
  include DatabaseTestSetup

  def setup
    setup_test_db
    @recorder = FunCi::DbRecorder.new(@db)
  end

  def teardown
    teardown_test_db
  end

  def test_should_update_stage_job_to_completed
    # Given a recorder with a running stage
    @recorder.create_run(commit_hash: "abc1234", branch: "main")
    job_id = @recorder.start_stage("build")
    # When the stage ends with success
    @recorder.end_stage(job_id, "completed")
    # Then the stage job should be completed
    job = FunCi::StageJob.find(@db, job_id)
    assert_equal "completed", job[:status],
      "Stage job should be completed after end_stage"
  end

  def test_should_update_stage_job_to_failed
    # Given a recorder with a running stage
    @recorder.create_run(commit_hash: "abc1234", branch: "main")
    job_id = @recorder.start_stage("build")
    # When the stage ends with failure
    @recorder.end_stage(job_id, "failed")
    # Then the stage job should be failed
    job = FunCi::StageJob.find(@db, job_id)
    assert_equal "failed", job[:status],
      "Stage job should be failed after end_stage"
  end

  def test_should_ignore_nil_job_id
    # Given a recorder
    # When end_stage is called with nil (the guard clause)
    @recorder.end_stage(nil, "completed")
    # Then no error should occur (implicit: no exception raised)
  end
end

class TestDbRecorderForBackground < Minitest::Test
  def test_should_record_results_via_background_recorder
    # Given a pipeline run created by the parent recorder
    dir = Dir.mktmpdir("fun-ci-test")
    db_path = File.join(dir, "pipeline.db")
    db = FunCi::Database.connection(db_path)
    FunCi::Database.migrate!(db)
    parent_recorder = FunCi::DbRecorder.new(db)
    parent_recorder.create_run(commit_hash: "abc1234", branch: "main")
    job_id = parent_recorder.start_stage("slow")
    pipeline_run_id = parent_recorder.pipeline_run_id
    parent_recorder.close
    # When a background recorder is created from db_path and pipeline_run_id
    bg_recorder = FunCi::DbRecorder.for_background(db_path, pipeline_run_id)
    bg_recorder.end_stage(job_id, "completed")
    bg_recorder.complete_run
    bg_recorder.close
    # Then the results should be persisted in the database
    verify_db = FunCi::Database.connection(db_path)
    run = FunCi::PipelineRun.find_by_commit(verify_db, "abc1234").first
    assert_equal "completed", run[:status],
      "Background recorder should record pipeline completion"
  ensure
    verify_db&.close
    FileUtils.remove_entry(dir) rescue nil
  end
end

class TestDbRecorderTerminalStatus < Minitest::Test
  include DatabaseTestSetup

  def setup
    setup_test_db
    @recorder = FunCi::DbRecorder.new(@db)
  end

  def teardown
    teardown_test_db
  end

  def test_should_mark_pipeline_run_completed
    # Given a recorder with a running pipeline
    @recorder.create_run(commit_hash: "abc1234", branch: "main")
    @recorder.start_stage("build")
    # When complete_run is called
    @recorder.complete_run
    # Then the pipeline run should be completed
    run = FunCi::PipelineRun.find_by_commit(@db, "abc1234").first
    assert_equal "completed", run[:status],
      "Pipeline run should be completed"
  end

  def test_should_mark_pipeline_run_failed
    # Given a recorder with a running pipeline
    @recorder.create_run(commit_hash: "abc1234", branch: "main")
    @recorder.start_stage("build")
    # When fail_run is called
    @recorder.fail_run
    # Then the pipeline run should be failed
    run = FunCi::PipelineRun.find_by_commit(@db, "abc1234").first
    assert_equal "failed", run[:status],
      "Pipeline run should be failed"
  end
end
