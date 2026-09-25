# frozen_string_literal: true

require_relative "trigger_cli_shared"

# Acceptance tests for stage time budget enforcement.
#
# Covers: lint stage 30s budget, build stage 30s budget,
# fast suite 10s budget, slow suite 5min budget. All timeouts are simulated
# via command_runner DI -- no real time elapses.

class TestTriggerCliTimeBudgets < Minitest::Test
  def teardown
    @client&.close
  end

  def test_should_kill_fast_suite_when_it_exceeds_10_second_budget
    trigger_timing_out_on("fast.sh")
    refute_equal 0, @client.exit_code, "Should fail when fast suite exceeds budget"
    assert_match(/time budget/i, @client.stdout, "Should mention time budget")
    assert_match(/Fast suite killed/i, @client.stdout, "Should mention fast suite was killed")
  end

  def test_should_record_slow_suite_timeout_when_budget_exceeded
    trigger_timing_out_on("slow.sh", background_launcher: SYNC_LAUNCHER)
    runs = @client.pipeline_runs_for(commit_hash: "abc1234")
    jobs = @client.stage_jobs_for(pipeline_run_id: runs.first[:id])
    slow_job = jobs.find { |j| j[:stage] == "slow" }
    assert_equal "timed_out", slow_job[:status],
                 "Slow stage should be marked timed_out when budget exceeded"
  end

  def test_should_kill_lint_stage_when_it_exceeds_30_second_budget
    trigger_timing_out_on("lint.sh")
    refute_equal 0, @client.exit_code, "Should fail when lint exceeds budget"
    assert_match(/time budget/i, @client.stdout, "Should mention time budget")
    assert_match(/Lint killed/i, @client.stdout, "Should mention lint was killed")
  end

  def test_should_kill_build_stage_when_it_exceeds_30_second_budget
    trigger_timing_out_on("build.sh")
    refute_equal 0, @client.exit_code, "Should fail when build exceeds budget"
    assert_match(/time budget/i, @client.stdout, "Should mention time budget")
    assert_match(/Build killed/i, @client.stdout, "Should mention build was killed")
  end

  private

  def trigger_timing_out_on(script, **client_options)
    @client = TriggerCliClient.new(command_runner: timing_out_on(script), **client_options)
    @client.trigger(commit_hash: "abc1234", branch: "main")
  end

  def timing_out_on(script)
    lambda { |cmd|
      raise Timeout::Error, "budget exceeded" if cmd.include?(script)

      ["", FakeStatus.new(true, 0)]
    }
  end
end
