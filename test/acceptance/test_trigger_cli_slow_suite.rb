# frozen_string_literal: true

require_relative "trigger_cli_shared"

class TestTriggerCliSlowSuiteResults < Minitest::Test
  def teardown
    @client&.close
  end

  def test_should_record_slow_suite_pass_in_database
    run, slow_job = trigger_with_slow_suite(-> { ["", FakeStatus.new(true, 0)] })
    assert_equal "completed", slow_job[:status],
                 "Slow stage should be marked completed"
    assert_equal "completed", run[:status],
                 "Pipeline should be marked completed when all stages pass"
  end

  def test_should_mark_pipeline_as_failed_when_slow_suite_fails
    run, slow_job = trigger_with_slow_suite(-> { ["", FakeStatus.new(false, 1)] })
    assert_equal "failed", slow_job[:status],
                 "Slow stage should be marked failed"
    assert_equal "failed", run[:status],
                 "Pipeline should be marked failed when slow suite fails"
  end

  def test_should_record_slow_suite_timeout_in_database
    run, slow_job = trigger_with_slow_suite(-> { raise Timeout::Error, "simulated timeout" })
    assert_equal "timed_out", slow_job[:status],
                 "Slow stage should be marked timed_out when budget exceeded"
    assert_equal "failed", run[:status],
                 "Pipeline should be marked failed when slow suite times out"
  end

  private

  def trigger_with_slow_suite(slow_outcome)
    runner = ->(cmd) { cmd.include?("slow.sh") ? slow_outcome.call : ["", FakeStatus.new(true, 0)] }
    @client = TriggerCliClient.new(command_runner: runner, background_launcher: SYNC_LAUNCHER)
    @client.trigger(commit_hash: "abc1234", branch: "main")
    run = @client.pipeline_runs_for(commit_hash: "abc1234").first
    jobs = @client.stage_jobs_for(pipeline_run_id: run[:id])
    [run, jobs.find { |j| j[:stage] == "slow" }]
  end
end
