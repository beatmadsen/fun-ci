# frozen_string_literal: true

require_relative "trigger_cli_shared"

# Acceptance tests for background process behavior.
#
# Covers: the slow suite's deadline and result, a build timeout, and the
# foreground result when the background suite fails. Commands are injected,
# so no process exists here; killing a stage's whole process group is
# covered with real processes by AT-1.6.

class TestTriggerCliBackgroundProcess < Minitest::Test
  def teardown
    @client&.close
  end

  def test_should_return_fast_suite_result_when_slow_suite_times_out
    trigger_with(timing_out_script_runner("slow.sh"), SYNC_LAUNCHER)
    assert_equal 0, @client.exit_code, "Foreground should return 0 for fast suite"
  end

  def test_should_record_the_slow_suite_as_timed_out_when_it_overruns
    trigger_with(timing_out_script_runner("slow.sh"), SYNC_LAUNCHER)
    runs = @client.pipeline_runs_for(commit_hash: "abc1234")
    slow_job = @client.stage_jobs_for(pipeline_run_id: runs.first[:id]).find { |j| j[:stage] == "slow" }
    assert_equal "timed_out", slow_job[:status], "Slow stage should be timed_out"
  end

  def test_should_run_the_slow_suite
    trigger_with(script_simulating_runner, SYNC_LAUNCHER)

    assert @client.ran?("slow.sh")
  end

  def test_should_fail_when_build_times_out
    trigger_with(timing_out_script_runner("build.sh"))
    refute_equal 0, @client.exit_code, "Should fail on build timeout"
  end

  def test_should_report_a_timed_out_build_as_killed
    trigger_with(timing_out_script_runner("build.sh"))
    assert_match(/killed/i, @client.stdout, "Should mention process was killed")
  end

  def test_should_report_fast_suite_result_when_background_process_crashes
    trigger_with(failing_script_runner("slow.sh"), SYNC_LAUNCHER)
    assert_equal 0, @client.exit_code,
                 "Should return 0 because fast suite passed, regardless of slow suite"
  end

  private

  def trigger_with(command_runner, background_launcher = nil)
    @client = TriggerCliClient.open(command_runner: command_runner, background_launcher: background_launcher)
    @client.trigger(commit_hash: "abc1234", branch: "main")
  end
end
