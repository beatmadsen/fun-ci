# frozen_string_literal: true

require_relative "trigger_cli_shared"

# Acceptance tests for database integration (pipeline runs and stage jobs).
#
# Covers: pipeline_run creation, stage_job recording for each stage,
# status transitions (completed/failed), and production-path recording
# via BackgroundWrapper.

class TestTriggerCliDatabaseIntegration < Minitest::Test
  def setup
    @client = TriggerCliClient.new
  end

  def teardown
    @client.close
  end

  def test_should_create_pipeline_run_in_database_when_triggered
    @client.trigger(commit_hash: "abc1234", branch: "main")
    runs = @client.pipeline_runs_for(commit_hash: "abc1234")
    refute_empty runs, "Should create a pipeline_run record in the database"
    assert_equal "abc1234", runs.first[:commit_hash], "Should store the commit hash"
    assert_equal "main", runs.first[:branch], "Should store the branch"
  end

  def test_should_record_stage_jobs_for_each_stage_when_all_pass
    @client.trigger(commit_hash: "abc1234", branch: "main")
    runs = @client.pipeline_runs_for(commit_hash: "abc1234")
    jobs = @client.stage_jobs_for(pipeline_run_id: runs.first[:id])
    stages = jobs.map { |j| j[:stage] }
    assert_includes stages, "build", "Should record a stage_job for build"
    assert_includes stages, "fast", "Should record a stage_job for fast"
    assert_includes stages, "slow", "Should record a stage_job for slow"
  end

  def test_should_mark_stages_as_completed_when_scripts_pass
    @client.trigger(commit_hash: "abc1234", branch: "main")
    runs = @client.pipeline_runs_for(commit_hash: "abc1234")
    jobs = @client.stage_jobs_for(pipeline_run_id: runs.first[:id])
    build_job = jobs.find { |j| j[:stage] == "build" }
    fast_job = jobs.find { |j| j[:stage] == "fast" }
    assert_equal "completed", build_job[:status], "Build stage should be marked completed"
    assert_equal "completed", fast_job[:status], "Fast stage should be marked completed"
  end

  def test_should_mark_stage_as_failed_when_script_fails
    @client.trigger(commit_hash: "abc1234", branch: "main",
      scripts: { "build.sh" => "exit 1" })
    runs = @client.pipeline_runs_for(commit_hash: "abc1234")
    jobs = @client.stage_jobs_for(pipeline_run_id: runs.first[:id])
    build_job = jobs.find { |j| j[:stage] == "build" }
    assert_equal "failed", build_job[:status], "Build stage should be marked failed"
  end

  def test_should_not_mark_pipeline_run_as_completed_before_slow_suite_finishes
    @client.trigger(commit_hash: "abc1234", branch: "main")
    runs = @client.pipeline_runs_for(commit_hash: "abc1234")
    refute_equal "completed", runs.first[:status],
      "Pipeline should NOT be marked completed before slow suite finishes"
  end

  def test_should_mark_pipeline_run_as_failed_when_build_fails
    @client.trigger(commit_hash: "abc1234", branch: "main",
      scripts: { "build.sh" => "exit 1" })
    runs = @client.pipeline_runs_for(commit_hash: "abc1234")
    assert_equal "failed", runs.first[:status], "Pipeline should be marked failed"
  end
end

class TestTriggerCliProductionSlowSuiteRecording < Minitest::Test
  def teardown
    @client&.close
  end

  def test_should_record_slow_suite_result_when_using_production_path
    @client = TriggerCliClient.new(background_launcher: SYNC_LAUNCHER)
    @client.trigger(commit_hash: "abc1234", branch: "main")
    runs = @client.pipeline_runs_for(commit_hash: "abc1234")
    jobs = @client.stage_jobs_for(pipeline_run_id: runs.first[:id])
    slow_job = jobs.find { |j| j[:stage] == "slow" }
    assert_equal "completed", slow_job[:status],
      "Production path should record slow suite result via BackgroundWrapper"
    assert_equal "completed", runs.first[:status],
      "Pipeline should be completed when all stages pass via production path"
  end

  def test_should_record_slow_suite_failure_when_using_production_path
    @client = TriggerCliClient.new(background_launcher: SYNC_LAUNCHER)
    @client.trigger(commit_hash: "abc1234", branch: "main",
      scripts: { "slow.sh" => "exit 1" })
    runs = @client.pipeline_runs_for(commit_hash: "abc1234")
    jobs = @client.stage_jobs_for(pipeline_run_id: runs.first[:id])
    slow_job = jobs.find { |j| j[:stage] == "slow" }
    assert_equal "failed", slow_job[:status],
      "Production path should record slow suite failure"
    assert_equal "failed", runs.first[:status],
      "Pipeline should be failed when slow suite fails via production path"
  end
end
