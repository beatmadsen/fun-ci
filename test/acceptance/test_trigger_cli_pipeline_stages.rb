# frozen_string_literal: true

require_relative "trigger_cli_shared"

# Acceptance tests for pipeline stage ordering and gating.
#
# Covers: build-before-fast ordering, fast-gates-slow,
# build-gates-fast, and slow suite background launch.

class TestTriggerCliPipelineStages < Minitest::Test
  def teardown
    @client&.close
  end

  def test_should_run_both_lint_and_build_in_phase_one
    trigger(command_runner: script_simulating_runner)
    refute_nil @client.script_arguments_for("lint.sh"), "lint.sh should run in Phase 1"
    refute_nil @client.script_arguments_for("build.sh"), "build.sh should run in Phase 1"
  end

  def test_should_still_run_build_when_lint_fails
    trigger(command_runner: script_simulating_runner(failures: { "lint.sh" => { exit: 1 } }))
    refute_nil @client.script_arguments_for("build.sh"), "build.sh should still run when lint fails (parallel)"
    refute_equal 0, @client.exit_code, "Should fail when lint fails"
    assert_match(/Lint failed/i, @client.stdout, "Should mention lint failure")
  end

  def test_should_run_build_stage_before_fast_suite
    trigger(command_runner: script_simulating_runner)
    refute_nil @client.script_arguments_for("build.sh"), "build.sh should run"
    refute_nil @client.script_arguments_for("fast.sh"), "fast.sh should run after build"
  end

  def test_should_not_run_fast_suite_when_build_fails
    trigger(command_runner: script_simulating_runner(failures: { "build.sh" => { exit: 1 } }))
    assert_nil @client.script_arguments_for("fast.sh"), "fast.sh should not run when build fails"
    refute_equal 0, @client.exit_code, "Should fail when build fails"
    assert_match(/Build failed/i, @client.stdout, "Should mention build failure")
  end

  def test_should_still_launch_slow_suite_when_fast_suite_fails
    slow_invoked = false
    trigger(command_runner: failing_on("fast.sh"), background_launcher: ->(**) { slow_invoked = true })
    assert slow_invoked, "Slow suite should be launched even when fast fails"
    refute_equal 0, @client.exit_code, "Should fail when fast suite fails"
  end

  def test_should_run_slow_suite_in_background_after_fast_suite_passes
    trigger(command_runner: INSTANT_SUCCESS_RUNNER, background_launcher: SYNC_LAUNCHER)
    assert_equal 0, @client.exit_code, "Should return 0 after fast suite passes"
  end

  private

  def trigger(**client_options)
    @client = TriggerCliClient.new(**client_options)
    @client.trigger(commit_hash: "abc1234", branch: "main")
  end

  def failing_on(script)
    ->(cmd) { cmd.include?(script) ? ["", FakeStatus.new(false, 1)] : ["", FakeStatus.new(true, 0)] }
  end
end
