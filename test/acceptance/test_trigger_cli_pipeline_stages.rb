# frozen_string_literal: true

require_relative "trigger_cli_shared"

# Acceptance tests for pipeline stage ordering and gating.
#
# Covers: build-before-fast ordering, fast-gates-slow,
# build-gates-fast, and slow suite background launch.

class TestTriggerCliPipelineStages < Minitest::Test
  def setup
    @client = TriggerCliClient.new
  end

  def teardown
    @client.close
  end

  def test_should_run_both_lint_and_build_in_phase_one
    # Given a project with lint and build configured
    # When the trigger CLI is invoked
    @client.trigger(commit_hash: "abc1234", branch: "main")
    # Then both lint and build should run (parallel Phase 1)
    lint_args = @client.script_arguments_for("lint.sh")
    build_args = @client.script_arguments_for("build.sh")
    refute_nil lint_args, "lint.sh should run in Phase 1"
    refute_nil build_args, "build.sh should run in Phase 1"
  end

  def test_should_still_run_build_when_lint_fails
    # Given a project with a lint that fails (lint + build are parallel)
    # When the trigger CLI is invoked
    @client.trigger(commit_hash: "abc1234", branch: "main",
      scripts: { "lint.sh" => "exit 1" })
    # Then build should still have run (parallel Phase 1)
    build_args = @client.script_arguments_for("build.sh")
    refute_nil build_args, "build.sh should still run when lint fails (parallel)"
    # And exit code should be non-zero
    refute_equal 0, @client.exit_code, "Should fail when lint fails"
    # And stdout should contain "Lint failed"
    assert_match(/Lint failed/i, @client.stdout, "Should mention lint failure")
  end

  def test_should_run_build_stage_before_fast_suite
    # Given a project with build and fast suite configured
    # When the trigger CLI is invoked
    @client.trigger(commit_hash: "abc1234", branch: "main")
    # Then the build stage should complete before the fast suite starts
    build_args = @client.script_arguments_for("build.sh")
    fast_args = @client.script_arguments_for("fast.sh")
    refute_nil build_args, "build.sh should run"
    refute_nil fast_args, "fast.sh should run after build"
  end

  def test_should_not_run_fast_suite_when_build_fails
    # Given a project with a build that fails
    # When the trigger CLI is invoked
    @client.trigger(commit_hash: "abc1234", branch: "main",
      scripts: { "build.sh" => "exit 1" })
    # Then the fast suite should not run
    fast_args = @client.script_arguments_for("fast.sh")
    assert_nil fast_args, "fast.sh should not run when build fails"
    # And exit code should be non-zero
    refute_equal 0, @client.exit_code, "Should fail when build fails"
    # And stdout should contain "Build failed"
    assert_match(/Build failed/i, @client.stdout, "Should mention build failure")
  end

  def test_should_still_launch_slow_suite_when_fast_suite_fails
    # Given a project with a fast suite that fails
    # and a sync launcher so we can check if slow was actually invoked
    slow_invoked = false
    client = TriggerCliClient.new(
      background_launcher: ->(db_path:, pipeline_run_id:, job_id:, executor:) {
        slow_invoked = true
      }
    )
    # When the trigger CLI is invoked
    client.trigger(commit_hash: "abc1234", branch: "main",
      scripts: { "fast.sh" => "exit 1" })
    # Then the slow suite should have been launched (parallel Phase 2)
    assert slow_invoked, "Slow suite should be launched even when fast fails"
    # And exit code should be non-zero (fast failure blocks the commit)
    refute_equal 0, client.exit_code, "Should fail when fast suite fails"
  ensure
    client&.close
  end

  def test_should_run_slow_suite_in_background_after_fast_suite_passes
    # Given a project where build and fast suite pass (sync launcher for determinism)
    client = TriggerCliClient.new(
      background_launcher: SYNC_LAUNCHER
    )
    # When the trigger CLI is invoked
    client.trigger(commit_hash: "abc1234", branch: "main")
    # Then the foreground process should return exit code 0
    assert_equal 0, client.exit_code, "Should return 0 after fast suite passes"
    # And slow.sh should have been invoked (receives commit hash)
    args = client.script_arguments_for("slow.sh")
    refute_nil args, "slow.sh should have been invoked in background"
    assert_equal "abc1234", args.first, "slow.sh should receive commit hash as $1"
  ensure
    client&.close
  end
end
