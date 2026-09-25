# frozen_string_literal: true

require_relative "trigger_cli_shared"

# Acceptance tests for database integration (pipeline runs and stage jobs).
#
# Covers: pipeline_run creation, stage_job recording for each stage,
# status transitions (completed/failed), and production-path recording
# via BackgroundWrapper.

module TriggerCliDbSteps
  def teardown
    @client&.close
  end

  def trigger(**client_options)
    @client = TriggerCliClient.new(command_runner: INSTANT_SUCCESS_RUNNER, **client_options)
    @client.trigger(commit_hash: "abc1234", branch: "main")
  end

  def failing_on(script)
    ->(cmd) { cmd.include?(script) ? ["", FakeStatus.new(false, 1)] : ["", FakeStatus.new(true, 0)] }
  end

  def pipeline_run
    @client.pipeline_runs_for(commit_hash: "abc1234").first
  end

  def jobs
    @client.stage_jobs_for(pipeline_run_id: pipeline_run[:id])
  end

  def job_status(stage)
    jobs.find { |j| j[:stage] == stage }[:status]
  end
end

class TestTriggerCliDatabaseIntegration < Minitest::Test
  include TriggerCliDbSteps

  def test_should_create_pipeline_run_in_database_when_triggered
    trigger
    runs = @client.pipeline_runs_for(commit_hash: "abc1234")
    refute_empty runs, "Should create a pipeline_run record in the database"
    assert_equal "abc1234", runs.first[:commit_hash], "Should store the commit hash"
    assert_equal "main", runs.first[:branch], "Should store the branch"
  end

  def test_should_record_stage_jobs_for_each_stage_when_all_pass
    trigger
    stages = jobs.map { |j| j[:stage] }
    assert_includes stages, "lint", "Should record a stage_job for lint"
    assert_includes stages, "build", "Should record a stage_job for build"
    assert_includes stages, "fast", "Should record a stage_job for fast"
    assert_includes stages, "slow", "Should record a stage_job for slow"
  end

  def test_should_mark_stages_as_completed_when_scripts_pass
    trigger
    assert_equal "completed", job_status("lint"), "Lint stage should be marked completed"
    assert_equal "completed", job_status("build"), "Build stage should be marked completed"
    assert_equal "completed", job_status("fast"), "Fast stage should be marked completed"
  end

  def test_should_mark_stage_as_failed_when_script_fails
    trigger(command_runner: failing_on("build.sh"))
    assert_equal "failed", job_status("build"), "Build stage should be marked failed"
  end

  def test_should_mark_lint_stage_as_failed_when_lint_script_fails
    trigger(command_runner: failing_on("lint.sh"))
    assert_equal "failed", job_status("lint"), "Lint stage should be marked failed"
  end

  def test_should_mark_pipeline_run_as_failed_when_lint_fails
    trigger(command_runner: failing_on("lint.sh"))
    assert_equal "failed", pipeline_run[:status], "Pipeline should be marked failed when lint fails"
  end

  def test_should_not_mark_pipeline_run_as_completed_before_slow_suite_finishes
    trigger
    refute_equal "completed", pipeline_run[:status],
                 "Pipeline should NOT be marked completed before slow suite finishes"
  end

  def test_should_mark_pipeline_run_as_failed_when_build_fails
    trigger(command_runner: failing_on("build.sh"))
    assert_equal "failed", pipeline_run[:status], "Pipeline should be marked failed"
  end
end

class TestTriggerCliProductionSlowSuiteRecording < Minitest::Test
  include TriggerCliDbSteps

  def test_should_record_slow_suite_result_when_using_production_path
    trigger(background_launcher: SYNC_LAUNCHER)
    assert_equal "completed", job_status("slow"),
                 "Production path should record slow suite result via BackgroundWrapper"
    assert_equal "completed", pipeline_run[:status],
                 "Pipeline should be completed when all stages pass via production path"
  end

  def test_should_record_slow_suite_failure_when_using_production_path
    trigger(command_runner: failing_on("slow.sh"), background_launcher: SYNC_LAUNCHER)
    assert_equal "failed", job_status("slow"),
                 "Production path should record slow suite failure"
    assert_equal "failed", pipeline_run[:status],
                 "Pipeline should be failed when slow suite fails via production path"
  end
end
