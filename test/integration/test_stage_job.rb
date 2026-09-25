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
    id = FunCi::Persistence::StageJob.create(@db, pipeline_run_id: @run_id, stage: "build")
    assert_kind_of Integer, id, "Should return an integer id"
    assert_predicate id, :positive?, "Id should be positive"
  end

  def test_should_find_nothing_for_an_unknown_id
    assert_nil FunCi::Persistence::StageJob.find(@db, 99_999)
  end

  def test_should_refuse_a_status_it_has_no_timestamp_for
    id = FunCi::Persistence::StageJob.create(@db, pipeline_run_id: @run_id, stage: "build")

    assert_raises(KeyError) { FunCi::Persistence::StageJob.update_status(@db, id, "paused") }
  end

  def test_should_default_status_to_scheduled
    id = FunCi::Persistence::StageJob.create(@db, pipeline_run_id: @run_id, stage: "build")
    job = FunCi::Persistence::StageJob.find(@db, id)
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
    id = FunCi::Persistence::StageJob.create(@db, pipeline_run_id: @run_id, stage: "build")
    FunCi::Persistence::StageJob.update_status(@db, id, "running")
    job = FunCi::Persistence::StageJob.find(@db, id)
    refute_nil job[:started_at], "Should set started_at when running"
  end

  def test_should_set_completed_at_when_transitioning_to_terminal_state
    id = FunCi::Persistence::StageJob.create(@db, pipeline_run_id: @run_id, stage: "build")
    FunCi::Persistence::StageJob.update_status(@db, id, "running")
    FunCi::Persistence::StageJob.update_status(@db, id, "completed")
    job = FunCi::Persistence::StageJob.find(@db, id)
    refute_nil job[:completed_at], "Should set completed_at when completed"
  end

  def test_should_not_set_completed_at_when_transitioning_to_running
    id = FunCi::Persistence::StageJob.create(@db, pipeline_run_id: @run_id, stage: "build")
    FunCi::Persistence::StageJob.update_status(@db, id, "running")
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
    job = job_timed(Time.utc(2026, 1, 1, 12, 0, 0), Time.utc(2026, 1, 1, 12, 0, 5))
    duration = FunCi::Persistence::StageJob.elapsed_duration(job)
    assert_in_delta 5.0, duration, 0.01, "Should calculate 5 seconds elapsed"
  end

  def test_should_return_nil_elapsed_duration_when_not_started
    id = FunCi::Persistence::StageJob.create(@db, pipeline_run_id: @run_id, stage: "build")
    job = FunCi::Persistence::StageJob.find(@db, id)
    duration = FunCi::Persistence::StageJob.elapsed_duration(job)
    assert_nil duration, "Should return nil when job has not started"
  end

  def test_should_return_nil_elapsed_duration_when_still_running
    id = FunCi::Persistence::StageJob.create(@db, pipeline_run_id: @run_id, stage: "build")
    FunCi::Persistence::StageJob.update_status(@db, id, "running")
    job = FunCi::Persistence::StageJob.find(@db, id)
    duration = FunCi::Persistence::StageJob.elapsed_duration(job)
    assert_nil duration, "Should return nil when job is still running"
  end

  private

  def job_timed(started, completed)
    id = FunCi::Persistence::StageJob.create(@db, pipeline_run_id: @run_id, stage: "build")
    @db.execute("UPDATE stage_jobs SET started_at = ?, completed_at = ? WHERE id = ?",
                [started.iso8601, completed.iso8601, id])
    FunCi::Persistence::StageJob.find(@db, id)
  end
end
