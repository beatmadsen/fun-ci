# frozen_string_literal: true

require_relative "../test_helper"
require "stringio"
require "tmpdir"
require "fun_ci/trigger"

# Tests for Phase 1 parallel execution: lint + build run concurrently.
# Both must pass for Phase 2 (fast + slow) to proceed.

class TestTriggerParallelPhaseOne < Minitest::Test
  include FunCiTestProject

  def make_trigger(dir, commit_hash: "abc1234", command_runner: nil, time_budgets: {})
    stdout = StringIO.new
    stderr = StringIO.new
    launcher = ->(db_path:, pipeline_run_id:, job_id:, executor:) {
      FunCi::BackgroundWrapper.new(
        recorder: FakeRecorder.new, job_id: job_id, executor: executor
      ).run
    }
    trigger = FunCi::Trigger.new(
      project_root: dir,
      commit_hash: commit_hash,
      branch: "main",
      stdout: stdout,
      stderr: stderr,
      command_runner: command_runner,
      commit_validator: ->(_h) { true },
      background_launcher: launcher,
      time_budgets: time_budgets
    )
    [trigger, stdout, stderr]
  end

  def test_should_run_build_even_when_lint_fails
    # Given a project where lint fails
    Dir.mktmpdir("fun-ci-test") do |dir|
      make_project_with_scripts(dir)
      invocations = []
      fake_runner = ->(cmd) {
        invocations << cmd
        if cmd.include?("lint.sh")
          ["lint errors found", FakeStatus.new(false, 1)]
        else
          ["", FakeStatus.new(true, 0)]
        end
      }
      trigger, = make_trigger(dir, command_runner: fake_runner)
      # When the trigger is run
      trigger.run
      # Then build.sh should STILL have been invoked (parallel execution)
      build_cmd = invocations.find { |cmd| cmd.include?("build.sh") }
      refute_nil build_cmd, "Build should run even when lint fails (parallel Phase 1)"
    end
  end

  def test_should_run_lint_even_when_build_fails
    # Given a project where build fails
    Dir.mktmpdir("fun-ci-test") do |dir|
      make_project_with_scripts(dir)
      invocations = []
      fake_runner = ->(cmd) {
        invocations << cmd
        if cmd.include?("build.sh")
          ["build error", FakeStatus.new(false, 1)]
        else
          ["", FakeStatus.new(true, 0)]
        end
      }
      trigger, = make_trigger(dir, command_runner: fake_runner)
      # When the trigger is run
      trigger.run
      # Then lint.sh should have been invoked (parallel execution)
      lint_cmd = invocations.find { |cmd| cmd.include?("lint.sh") }
      refute_nil lint_cmd, "Lint should run even when build fails (parallel Phase 1)"
    end
  end

  def test_should_not_run_fast_when_lint_fails_in_phase_one
    # Given a project where lint fails but build passes
    Dir.mktmpdir("fun-ci-test") do |dir|
      make_project_with_scripts(dir)
      invocations = []
      fake_runner = ->(cmd) {
        invocations << cmd
        if cmd.include?("lint.sh")
          ["lint errors", FakeStatus.new(false, 1)]
        else
          ["", FakeStatus.new(true, 0)]
        end
      }
      trigger, = make_trigger(dir, command_runner: fake_runner)
      # When the trigger is run
      exit_code = trigger.run
      # Then fast.sh should NOT have been invoked
      fast_cmd = invocations.find { |cmd| cmd.include?("fast.sh") }
      assert_nil fast_cmd, "Fast suite should not run when lint fails"
      # And exit code should be non-zero
      refute_equal 0, exit_code, "Should fail when lint fails"
    end
  end

  def test_should_not_run_fast_when_build_fails_in_phase_one
    # Given a project where build fails but lint passes
    Dir.mktmpdir("fun-ci-test") do |dir|
      make_project_with_scripts(dir)
      invocations = []
      fake_runner = ->(cmd) {
        invocations << cmd
        if cmd.include?("build.sh")
          ["build error", FakeStatus.new(false, 1)]
        else
          ["", FakeStatus.new(true, 0)]
        end
      }
      trigger, = make_trigger(dir, command_runner: fake_runner)
      # When the trigger is run
      exit_code = trigger.run
      # Then fast.sh should NOT have been invoked
      fast_cmd = invocations.find { |cmd| cmd.include?("fast.sh") }
      assert_nil fast_cmd, "Fast suite should not run when build fails"
      # And exit code should be non-zero
      refute_equal 0, exit_code, "Should fail when build fails"
    end
  end

  def test_should_report_both_failures_when_lint_and_build_both_fail
    # Given a project where both lint and build fail
    Dir.mktmpdir("fun-ci-test") do |dir|
      make_project_with_scripts(dir)
      fake_runner = ->(cmd) {
        if cmd.include?("lint.sh")
          ["lint errors", FakeStatus.new(false, 1)]
        elsif cmd.include?("build.sh")
          ["build errors", FakeStatus.new(false, 1)]
        else
          ["", FakeStatus.new(true, 0)]
        end
      }
      trigger, stdout, = make_trigger(dir, command_runner: fake_runner)
      # When the trigger is run
      exit_code = trigger.run
      # Then both failures should be reported
      assert_match(/Lint failed/i, stdout.string, "Should report lint failure")
      assert_match(/Build failed/i, stdout.string, "Should report build failure")
      # And exit code should be non-zero
      refute_equal 0, exit_code, "Should fail when both stages fail"
    end
  end

  def test_should_proceed_to_fast_when_both_lint_and_build_pass
    # Given a project where both lint and build pass
    Dir.mktmpdir("fun-ci-test") do |dir|
      make_project_with_scripts(dir)
      invocations = []
      fake_runner = ->(cmd) {
        invocations << cmd
        ["", FakeStatus.new(true, 0)]
      }
      trigger, = make_trigger(dir, command_runner: fake_runner)
      # When the trigger is run
      trigger.run
      # Then fast.sh should have been invoked
      fast_cmd = invocations.find { |cmd| cmd.include?("fast.sh") }
      refute_nil fast_cmd, "Fast suite should run when both lint and build pass"
    end
  end
end
