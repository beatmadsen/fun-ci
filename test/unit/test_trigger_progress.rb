# frozen_string_literal: true

require_relative "../test_helper"
require "stringio"
require "tmpdir"
require "fun_ci/trigger"

# Tests for progress feedback output during trigger execution.
# Verifies that the trigger reports stage results to stdout
# as each phase completes, giving git hook users visible feedback.

class TestTriggerProgressOnSuccess < Minitest::Test
  include FunCiTestProject

  def make_trigger(dir, command_runner:)
    stdout = StringIO.new
    launcher = ->(db_path:, pipeline_run_id:, job_id:, executor:) {
      FunCi::BackgroundWrapper.new(
        recorder: FakeRecorder.new, job_id: job_id, executor: executor
      ).run
    }
    trigger = FunCi::Trigger.new(
      project_root: dir,
      commit_hash: "abc1234",
      branch: "main",
      stdout: stdout,
      command_runner: command_runner,
      commit_validator: ->(_h) { true },
      background_launcher: launcher
    )
    [trigger, stdout]
  end

  def test_should_show_phase_one_passed_when_lint_and_build_succeed
    # Given a project where all stages pass
    Dir.mktmpdir("fun-ci-test") do |dir|
      make_project_with_scripts(dir)
      fake_runner = ->(cmd) { ["", FakeStatus.new(true, 0)] }
      trigger, stdout = make_trigger(dir, command_runner: fake_runner)
      # When the trigger is run
      trigger.run
      # Then stdout should show phase 1 passed with lint and build ok
      assert_match(/lint ok/, stdout.string, "Should show lint ok")
      assert_match(/build ok/, stdout.string, "Should show build ok")
      assert_match(/phase 1 passed/i, stdout.string, "Should show phase 1 passed")
    end
  end

  def test_should_show_fast_ok_and_slow_background_when_all_pass
    # Given a project where all stages pass
    Dir.mktmpdir("fun-ci-test") do |dir|
      make_project_with_scripts(dir)
      fake_runner = ->(cmd) { ["", FakeStatus.new(true, 0)] }
      trigger, stdout = make_trigger(dir, command_runner: fake_runner)
      # When the trigger is run
      trigger.run
      # Then stdout should show fast ok and slow running in background
      assert_match(/fast ok/, stdout.string, "Should show fast ok")
      assert_match(/slow.*background/i, stdout.string, "Should indicate slow in background")
    end
  end
end

class TestTriggerProgressOnFailure < Minitest::Test
  include FunCiTestProject

  def make_trigger(dir, command_runner:)
    stdout = StringIO.new
    noop_launcher = ->(db_path:, pipeline_run_id:, job_id:, executor:) {}
    trigger = FunCi::Trigger.new(
      project_root: dir,
      commit_hash: "abc1234",
      branch: "main",
      stdout: stdout,
      command_runner: command_runner,
      commit_validator: ->(_h) { true },
      background_launcher: noop_launcher
    )
    [trigger, stdout]
  end

  def test_should_show_phase_one_failed_when_lint_fails
    # Given a project where lint fails
    Dir.mktmpdir("fun-ci-test") do |dir|
      make_project_with_scripts(dir)
      fake_runner = ->(cmd) {
        if cmd.include?("lint.sh")
          ["lint errors", FakeStatus.new(false, 1)]
        else
          ["", FakeStatus.new(true, 0)]
        end
      }
      trigger, stdout = make_trigger(dir, command_runner: fake_runner)
      # When the trigger is run
      trigger.run
      # Then stdout should show lint FAIL and phase 1 failed
      assert_match(/lint FAIL/, stdout.string, "Should show lint FAIL")
      assert_match(/phase 1 failed/i, stdout.string, "Should summarize phase 1 failed")
    end
  end

  def test_should_show_fast_fail_when_fast_suite_fails
    # Given a project where fast fails but phase 1 passes
    Dir.mktmpdir("fun-ci-test") do |dir|
      make_project_with_scripts(dir)
      fake_runner = ->(cmd) {
        if cmd.include?("fast.sh")
          ["test failures", FakeStatus.new(false, 1)]
        else
          ["", FakeStatus.new(true, 0)]
        end
      }
      trigger, stdout = make_trigger(dir, command_runner: fake_runner)
      # When the trigger is run
      trigger.run
      # Then stdout should show fast FAIL
      assert_match(/fast FAIL/, stdout.string, "Should show fast FAIL")
    end
  end
end
