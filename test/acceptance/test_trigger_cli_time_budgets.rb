# frozen_string_literal: true

require_relative "trigger_cli_shared"

# Acceptance tests for stage time budget enforcement.
#
# Covers: fast suite 10s budget, slow suite 5min budget,
# build stage 30s budget. All timeouts are simulated
# via command_runner DI -- no real time elapses.

class TestTriggerCliTimeBudgets < Minitest::Test
  def setup
    @client = TriggerCliClient.new
  end

  def teardown
    @client.close
  end

  def test_should_kill_fast_suite_when_it_exceeds_10_second_budget
    # Given a command runner that simulates a timeout on the fast suite
    runner = ->(cmd) {
      raise Timeout::Error, "budget exceeded" if cmd.include?("fast.sh")
      ["", FakeStatus.new(true, 0)]
    }
    client = TriggerCliClient.new(command_runner: runner)
    # When the trigger CLI is invoked
    client.trigger(commit_hash: "abc1234", branch: "main")
    # Then exit code should be non-zero
    refute_equal 0, client.exit_code, "Should fail when fast suite exceeds budget"
    # And stdout should mention the time budget was exceeded
    assert_match(/time budget/i, client.stdout, "Should mention time budget")
    assert_match(/Fast suite killed/i, client.stdout, "Should mention fast suite was killed")
  ensure
    client&.close
  end

  def test_should_record_slow_suite_timeout_when_budget_exceeded
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
    # Then the slow stage_job should be "timed_out"
    runs = client.pipeline_runs_for(commit_hash: "abc1234")
    jobs = client.stage_jobs_for(pipeline_run_id: runs.first[:id])
    slow_job = jobs.find { |j| j[:stage] == "slow" }
    assert_equal "timed_out", slow_job[:status],
      "Slow stage should be marked timed_out when budget exceeded"
  ensure
    client&.close
  end

  def test_should_kill_build_stage_when_it_exceeds_30_second_budget
    # Given a command runner that simulates a timeout on the build stage
    runner = ->(cmd) {
      raise Timeout::Error, "budget exceeded" if cmd.include?("build.sh")
      ["", FakeStatus.new(true, 0)]
    }
    client = TriggerCliClient.new(command_runner: runner)
    # When the trigger CLI is invoked
    client.trigger(commit_hash: "abc1234", branch: "main")
    # Then exit code should be non-zero
    refute_equal 0, client.exit_code, "Should fail when build exceeds budget"
    # And stdout should mention the build time budget was exceeded
    assert_match(/time budget/i, client.stdout, "Should mention time budget")
    assert_match(/Build killed/i, client.stdout, "Should mention build was killed")
  ensure
    client&.close
  end
end
