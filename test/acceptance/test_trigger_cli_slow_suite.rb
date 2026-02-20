# frozen_string_literal: true

require_relative "trigger_cli_shared"

# Acceptance tests for slow suite result recording.
#
# Covers: slow suite pass/fail/timeout recorded in database,
# pipeline_run status reflects slow suite outcome.

class TestTriggerCliSlowSuiteResults < Minitest::Test
  def make_client(slow_exit:)
    slow_status = FakeStatus.new(slow_exit == 0, slow_exit)
    runner = ->(cmd) {
      if cmd.include?("slow.sh")
        ["", slow_status]
      else
        ["", FakeStatus.new(true, 0)]
      end
    }
    @client = TriggerCliClient.new(
      command_runner: runner,
      background_launcher: SYNC_LAUNCHER
    )
  end

  def teardown
    @client&.close
  end

  def test_should_record_slow_suite_pass_in_database
    # Given a project where all stages pass (slow.sh exits 0)
    client = make_client(slow_exit: 0)
    # When the trigger CLI is invoked
    client.trigger(commit_hash: "abc1234", branch: "main")
    # Then the slow stage_job should be "completed"
    runs = client.pipeline_runs_for(commit_hash: "abc1234")
    jobs = client.stage_jobs_for(pipeline_run_id: runs.first[:id])
    slow_job = jobs.find { |j| j[:stage] == "slow" }
    assert_equal "completed", slow_job[:status],
      "Slow stage should be marked completed"
    # And the pipeline_run should be "completed"
    assert_equal "completed", runs.first[:status],
      "Pipeline should be marked completed when all stages pass"
  end

  def test_should_mark_pipeline_as_failed_when_slow_suite_fails
    # Given a project where the slow suite fails
    client = make_client(slow_exit: 1)
    # When the trigger CLI is invoked
    client.trigger(commit_hash: "abc1234", branch: "main")
    # Then the slow stage_job should be "failed"
    runs = client.pipeline_runs_for(commit_hash: "abc1234")
    jobs = client.stage_jobs_for(pipeline_run_id: runs.first[:id])
    slow_job = jobs.find { |j| j[:stage] == "slow" }
    assert_equal "failed", slow_job[:status],
      "Slow stage should be marked failed"
    # And the pipeline_run should be "failed" (not "completed")
    assert_equal "failed", runs.first[:status],
      "Pipeline should be marked failed when slow suite fails"
  end

  def test_should_record_slow_suite_timeout_in_database
    # Given a project where the slow suite exceeds its time budget
    runner = ->(cmd) {
      if cmd.include?("slow.sh")
        raise Timeout::Error, "simulated timeout"
      else
        ["", FakeStatus.new(true, 0)]
      end
    }
    @client = TriggerCliClient.new(
      command_runner: runner,
      background_launcher: SYNC_LAUNCHER
    )
    # When the trigger CLI is invoked
    @client.trigger(commit_hash: "abc1234", branch: "main")
    # Then the slow stage_job should be "timed_out"
    runs = @client.pipeline_runs_for(commit_hash: "abc1234")
    jobs = @client.stage_jobs_for(pipeline_run_id: runs.first[:id])
    slow_job = jobs.find { |j| j[:stage] == "slow" }
    assert_equal "timed_out", slow_job[:status],
      "Slow stage should be marked timed_out when budget exceeded"
    # And the pipeline_run should be "failed"
    assert_equal "failed", runs.first[:status],
      "Pipeline should be marked failed when slow suite times out"
  end
end
