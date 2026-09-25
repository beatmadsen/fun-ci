# frozen_string_literal: true

require_relative "../test_helper"
require "tmpdir"
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

class TestDbRecorderStartStage < Minitest::Test
  include DbRecorderTestSetup

  def test_should_transition_pipeline_run_to_running_when_first_stage_starts
    create_run
    assert_equal "scheduled", run_status, "Precondition: run should be scheduled"
    @recorder.start_stage("build")
    assert_equal "running", run_status, "Pipeline run should transition to running when a stage starts"
  end

  def test_should_keep_pipeline_run_running_when_second_stage_starts
    create_run
    @recorder.start_stage("build")
    @recorder.start_stage("fast")
    assert_equal "running", run_status, "Pipeline run should remain running when additional stages start"
  end

  def test_should_create_stage_job_with_running_status
    create_run
    job = job(@recorder.start_stage("build"))
    assert_equal "running", job[:status], "Stage job should be running after start_stage"
    assert_equal "build", job[:stage], "Stage job should record the stage name"
  end

  def test_should_return_nil_when_no_pipeline_run_exists
    result = @recorder.start_stage("build")
    assert_nil result, "Should return nil when no pipeline run exists"
  end
end

class TestDbRecorderEndStage < Minitest::Test
  include DbRecorderTestSetup

  def test_should_update_stage_job_to_completed
    create_run
    job_id = @recorder.start_stage("build")
    @recorder.end_stage(job_id, "completed")
    assert_equal "completed", job(job_id)[:status], "Stage job should be completed after end_stage"
  end

  def test_should_update_stage_job_to_failed
    create_run
    job_id = @recorder.start_stage("build")
    @recorder.end_stage(job_id, "failed")
    assert_equal "failed", job(job_id)[:status], "Stage job should be failed after end_stage"
  end

  # Passes as long as the nil guard keeps end_stage from raising.
  def test_ending_a_nil_job_id_leaves_existing_stages_untouched
    create_run
    job_id = @recorder.start_stage("lint")
    @recorder.end_stage(nil, "completed")

    assert_equal "running", job(job_id)[:status]
  end
end

class TestDbRecorderForBackground < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("fun-ci-test")
    @db_path = File.join(@dir, "pipeline.db")
  end

  def teardown
    @verify_db&.close
    FileUtils.remove_entry(@dir)
  end

  def test_should_record_results_via_background_recorder
    job_id, pipeline_run_id = start_slow_stage_in_parent
    bg_recorder = FunCi::Persistence::DbRecorder.for_background(@db_path, pipeline_run_id)
    bg_recorder.end_stage(job_id, "completed")
    bg_recorder.complete_run
    bg_recorder.close
    assert_equal "completed", persisted_run_status, "Background recorder should record pipeline completion"
  end

  private

  def start_slow_stage_in_parent
    parent_recorder = FunCi::Persistence::DbRecorder.new(migrated_connection)
    parent_recorder.create_run(commit_hash: "abc1234", branch: "main")
    ids = [parent_recorder.start_stage("slow"), parent_recorder.pipeline_run_id]
    parent_recorder.close
    ids
  end

  def migrated_connection
    FunCi::Persistence::Database.connection(@db_path).tap { |db| FunCi::Persistence::Database.migrate!(db) }
  end

  def persisted_run_status
    @verify_db = FunCi::Persistence::Database.connection(@db_path)
    FunCi::Persistence::PipelineRun.find_by_commit(@verify_db, "abc1234").first[:status]
  end
end

class TestDbRecorderTerminalStatus < Minitest::Test
  include DbRecorderTestSetup

  def test_should_mark_pipeline_run_completed
    create_run
    @recorder.start_stage("build")
    @recorder.complete_run
    assert_equal "completed", run_status, "Pipeline run should be completed"
  end

  def test_should_mark_pipeline_run_failed
    create_run
    @recorder.start_stage("build")
    @recorder.fail_run
    assert_equal "failed", run_status, "Pipeline run should be failed"
  end
end
