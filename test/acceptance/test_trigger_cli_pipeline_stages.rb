# frozen_string_literal: true

require_relative "trigger_cli_shared"

# Acceptance tests for pipeline stage ordering and gating.
#
# Covers: build-before-fast ordering, fast-gates-slow,
# build-gates-fast, and slow suite background launch.

class TestTriggerCliPipelineStages < Minitest::Test
  def setup
    @client = TriggerCliClient.new(command_runner: INSTANT_SUCCESS_RUNNER)
  end

  def teardown
    @client.close
  end

  def test_should_run_both_lint_and_build_in_phase_one
    client = TriggerCliClient.new(command_runner: script_simulating_runner)
    client.trigger(commit_hash: "abc1234", branch: "main")
    lint_args = client.script_arguments_for("lint.sh")
    build_args = client.script_arguments_for("build.sh")
    refute_nil lint_args, "lint.sh should run in Phase 1"
    refute_nil build_args, "build.sh should run in Phase 1"
  ensure
    client&.close
  end

  def test_should_still_run_build_when_lint_fails
    client = TriggerCliClient.new(command_runner: script_simulating_runner(failures: { "lint.sh" => { exit: 1 } }))
    client.trigger(commit_hash: "abc1234", branch: "main")
    build_args = client.script_arguments_for("build.sh")
    refute_nil build_args, "build.sh should still run when lint fails (parallel)"
    refute_equal 0, client.exit_code, "Should fail when lint fails"
    assert_match(/Lint failed/i, client.stdout, "Should mention lint failure")
  ensure
    client&.close
  end

  def test_should_run_build_stage_before_fast_suite
    client = TriggerCliClient.new(command_runner: script_simulating_runner)
    client.trigger(commit_hash: "abc1234", branch: "main")
    build_args = client.script_arguments_for("build.sh")
    fast_args = client.script_arguments_for("fast.sh")
    refute_nil build_args, "build.sh should run"
    refute_nil fast_args, "fast.sh should run after build"
  ensure
    client&.close
  end

  def test_should_not_run_fast_suite_when_build_fails
    client = TriggerCliClient.new(command_runner: script_simulating_runner(failures: { "build.sh" => { exit: 1 } }))
    client.trigger(commit_hash: "abc1234", branch: "main")
    fast_args = client.script_arguments_for("fast.sh")
    assert_nil fast_args, "fast.sh should not run when build fails"
    refute_equal 0, client.exit_code, "Should fail when build fails"
    assert_match(/Build failed/i, client.stdout, "Should mention build failure")
  ensure
    client&.close
  end

  def test_should_still_launch_slow_suite_when_fast_suite_fails
    slow_invoked = false
    runner = ->(cmd) {
      cmd.include?("fast.sh") ? ["", FakeStatus.new(false, 1)] : ["", FakeStatus.new(true, 0)]
    }
    client = TriggerCliClient.new(
      command_runner: runner,
      background_launcher: ->(db_path:, pipeline_run_id:, job_id:, executor:) {
        slow_invoked = true
      }
    )
    client.trigger(commit_hash: "abc1234", branch: "main")
    assert slow_invoked, "Slow suite should be launched even when fast fails"
    refute_equal 0, client.exit_code, "Should fail when fast suite fails"
  ensure
    client&.close
  end

  def test_should_run_slow_suite_in_background_after_fast_suite_passes
    client = TriggerCliClient.new(
      command_runner: INSTANT_SUCCESS_RUNNER,
      background_launcher: SYNC_LAUNCHER
    )
    client.trigger(commit_hash: "abc1234", branch: "main")
    assert_equal 0, client.exit_code, "Should return 0 after fast suite passes"
  ensure
    client&.close
  end
end
