# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"
require "fun_ci/persistence/stage_job"
require "tmpdir"

class TestStageJobCreate < Minitest::Test
  include DatabaseTestSetup

  def setup
    setup_test_db
    @run_id = FunCi::Persistence::PipelineRun.create(@db, commit_hash: "abc123", branch: "main")
  end

  def teardown
    teardown_test_db
  end

  def test_should_create_a_stage_job_and_return_its_id
    # Given a pipeline run exists
    # When we create a stage job
    id = FunCi::Persistence::StageJob.create(@db, pipeline_run_id: @run_id, stage: "build")
    # Then we should get a positive integer id
    assert_kind_of Integer, id, "Should return an integer id"
    assert id > 0, "Id should be positive"
  end

  def test_should_default_status_to_scheduled
    # Given a newly created stage job
    id = FunCi::Persistence::StageJob.create(@db, pipeline_run_id: @run_id, stage: "build")
    # When we retrieve it
    job = FunCi::Persistence::StageJob.find(@db, id)
    # Then status should be scheduled
    assert_equal "scheduled", job[:status], "New stage job should default to scheduled"
  end
end

class TestStageJobUpdateStatus < Minitest::Test
  include DatabaseTestSetup

  def setup
    setup_test_db
    @run_id = FunCi::Persistence::PipelineRun.create(@db, commit_hash: "abc123", branch: "main")
  end

  def teardown
    teardown_test_db
  end

  def test_should_set_started_at_when_transitioning_to_running
    # Given a scheduled stage job
    id = FunCi::Persistence::StageJob.create(@db, pipeline_run_id: @run_id, stage: "build")
    # When we update status to running
    FunCi::Persistence::StageJob.update_status(@db, id, "running")
    # Then started_at should be set
    job = FunCi::Persistence::StageJob.find(@db, id)
    refute_nil job[:started_at], "Should set started_at when running"
  end

  def test_should_set_completed_at_when_transitioning_to_terminal_state
    # Given a running stage job
    id = FunCi::Persistence::StageJob.create(@db, pipeline_run_id: @run_id, stage: "build")
    FunCi::Persistence::StageJob.update_status(@db, id, "running")
    # When we update status to completed
    FunCi::Persistence::StageJob.update_status(@db, id, "completed")
    # Then completed_at should be set
    job = FunCi::Persistence::StageJob.find(@db, id)
    refute_nil job[:completed_at], "Should set completed_at when completed"
  end

  def test_should_not_set_completed_at_when_transitioning_to_running
    # Given a scheduled stage job
    id = FunCi::Persistence::StageJob.create(@db, pipeline_run_id: @run_id, stage: "build")
    # When we update status to running
    FunCi::Persistence::StageJob.update_status(@db, id, "running")
    # Then completed_at should remain nil
    job = FunCi::Persistence::StageJob.find(@db, id)
    assert_nil job[:completed_at], "Should not set completed_at for non-terminal state"
  end
end

class TestStageJobElapsedDuration < Minitest::Test
  include DatabaseTestSetup

  def setup
    setup_test_db
    @run_id = FunCi::Persistence::PipelineRun.create(@db, commit_hash: "abc123", branch: "main")
  end

  def teardown
    teardown_test_db
  end

  def test_should_calculate_elapsed_duration_for_completed_job
    # Given a stage job with known started_at and completed_at
    id = FunCi::Persistence::StageJob.create(@db, pipeline_run_id: @run_id, stage: "build")
    started = Time.utc(2026, 1, 1, 12, 0, 0)
    completed = Time.utc(2026, 1, 1, 12, 0, 5)
    @db.execute("UPDATE stage_jobs SET started_at = ?, completed_at = ? WHERE id = ?",
      [started.iso8601, completed.iso8601, id])
    # When we calculate elapsed duration
    job = FunCi::Persistence::StageJob.find(@db, id)
    duration = FunCi::Persistence::StageJob.elapsed_duration(job)
    # Then it should be 5 seconds
    assert_in_delta 5.0, duration, 0.01, "Should calculate 5 seconds elapsed"
  end

  def test_should_return_nil_elapsed_duration_when_not_started
    # Given a scheduled stage job (no started_at)
    id = FunCi::Persistence::StageJob.create(@db, pipeline_run_id: @run_id, stage: "build")
    # When we calculate elapsed duration
    job = FunCi::Persistence::StageJob.find(@db, id)
    duration = FunCi::Persistence::StageJob.elapsed_duration(job)
    # Then it should be nil
    assert_nil duration, "Should return nil when job has not started"
  end

  def test_should_return_nil_elapsed_duration_when_still_running
    # Given a running stage job (no completed_at)
    id = FunCi::Persistence::StageJob.create(@db, pipeline_run_id: @run_id, stage: "build")
    FunCi::Persistence::StageJob.update_status(@db, id, "running")
    # When we calculate elapsed duration
    job = FunCi::Persistence::StageJob.find(@db, id)
    duration = FunCi::Persistence::StageJob.elapsed_duration(job)
    # Then it should be nil (no completed_at yet)
    assert_nil duration, "Should return nil when job is still running"
  end
end
