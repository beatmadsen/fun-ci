# frozen_string_literal: true

require_relative "trigger_cli_shared"

# AT-7.1: a run's status follows from its stages alone, whichever of the fast
# suite and the background slow suite finishes first.
class TestRunStatusInAnyOrder < Minitest::Test
  # Holds the slow suite back until the test releases it, after the fast suite.
  class HeldSlowSuite
    def launcher = ->(**launch) { @launch = launch }
    def release = SYNC_LAUNCHER.call(**@launch)
  end

  PASS = ["", FakeStatus.new(true, 0)].freeze
  PASSING = ->(_cmd) { PASS }

  def teardown
    @client.close
  end

  def test_should_stay_failed_when_the_slow_suite_passes_after_the_fast_suite_failed
    held = HeldSlowSuite.new
    trigger(runner: failing_script_runner("fast.sh"), launcher: held.launcher)

    held.release

    assert_equal "failed", run_status
  end

  def test_should_not_count_as_passed_while_the_fast_suite_runs_after_the_slow_suite_passed
    trigger(runner: noting_status_when_fast_runs, launcher: SYNC_LAUNCHER)

    assert_equal [%w[running completed]], @seen, "[run, slow stage] when the fast suite ran"
  end

  def test_should_pass_once_the_fast_suite_passes_after_the_slow_suite_passed
    trigger(runner: PASSING, launcher: SYNC_LAUNCHER)

    assert_equal "completed", run_status
  end

  private

  def trigger(runner:, launcher:)
    @client = TriggerCliClient.open(command_runner: runner, background_launcher: launcher)
    @client.trigger(commit_hash: "abc1234", branch: "main")
  end

  def noting_status_when_fast_runs
    @seen = []
    lambda do |cmd|
      @seen << [run_status, slow_status] if cmd.include?("fast.sh")
      PASS
    end
  end

  def the_run = @client.pipeline_runs_for(commit_hash: "abc1234").first
  def run_status = the_run[:status]
  def slow_status = @client.stage_jobs_for(pipeline_run_id: the_run[:id]).find { |job| job[:stage] == "slow" }[:status]
end
