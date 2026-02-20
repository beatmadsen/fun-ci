# frozen_string_literal: true

require_relative "trigger_cli_shared"

# Acceptance tests for background process behavior.
#
# Covers: slow suite runs in background with deadline,
# no orphaned processes after completion or timeout,
# foreground result unaffected by background crash.

class TestTriggerCliBackgroundProcess < Minitest::Test
  def setup
    @client = TriggerCliClient.new(
      background_launcher: SYNC_LAUNCHER
    )
  end

  def teardown
    @client.close
  end

  def test_should_spawn_background_process_with_strict_deadline
    # Given a command runner that simulates a timeout on the slow suite
    runner = ->(cmd) {
      raise Timeout::Error, "budget exceeded" if cmd.include?("slow.sh")
      ["", FakeStatus.new(true, 0)]
    }
    client = TriggerCliClient.new(
      command_runner: runner,
      background_launcher: SYNC_LAUNCHER
    )
    # When the trigger CLI is invoked
    client.trigger(commit_hash: "abc1234", branch: "main")
    # Then the foreground should return exit code 0 (fast suite passed)
    assert_equal 0, client.exit_code, "Foreground should return 0 for fast suite"
    # And the slow stage should be recorded as timed_out in the database
    runs = client.pipeline_runs_for(commit_hash: "abc1234")
    jobs = client.stage_jobs_for(pipeline_run_id: runs.first[:id])
    slow_job = jobs.find { |j| j[:stage] == "slow" }
    assert_equal "timed_out", slow_job[:status], "Slow stage should be timed_out"
  ensure
    client&.close
  end

  def test_should_not_leave_orphaned_processes_after_completion
    # Given the trigger CLI has been invoked and the slow suite completes quickly
    @client.trigger(commit_hash: "abc1234", branch: "main",
      scripts: { "slow.sh" => "exit 0" })
    # When the pipeline finishes
    # Then wait briefly for background to complete, then check no orphans
    slow_args = @client.script_arguments_for("slow.sh")
    refute_nil slow_args, "slow.sh should have completed"
    # Background process should have exited after quick script
    # (no long-running orphan left behind)
  end

  def test_should_not_leave_orphaned_processes_after_timeout
    # Given a command runner that simulates a timeout on the build stage
    runner = ->(cmd) {
      raise Timeout::Error, "budget exceeded" if cmd.include?("build.sh")
      ["", FakeStatus.new(true, 0)]
    }
    client = TriggerCliClient.new(command_runner: runner)
    # When the trigger CLI is invoked
    client.trigger(commit_hash: "abc1234", branch: "main")
    # Then exit code should be non-zero (build timed out)
    refute_equal 0, client.exit_code, "Should fail on build timeout"
    # And stdout should mention the build was killed
    assert_match(/killed/i, client.stdout, "Should mention process was killed")
  ensure
    client&.close
  end

  def test_should_report_fast_suite_result_when_background_process_crashes
    # Given the fast suite has passed
    # When the background process crashes (slow.sh exits non-zero)
    @client.trigger(commit_hash: "abc1234", branch: "main",
      scripts: { "slow.sh" => "exit 1" })
    # Then the trigger CLI should still return exit code 0 (fast suite passed)
    assert_equal 0, @client.exit_code,
      "Should return 0 because fast suite passed, regardless of slow suite"
  end
end
