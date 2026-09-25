# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/slot_run_kit"

# Phase 1 runs lint and build side by side and both must pass. Phase 2 starts
# the slow suite in the background, then runs the fast suite.
class TestSlotRunStages < Minitest::Test
  include SlotRunKit

  def test_should_run_build_even_when_lint_fails
    assert runner_after({ "lint.sh" => failing("lint errors") }).ran?("build.sh")
  end

  def test_should_run_lint_even_when_build_fails
    assert runner_after({ "build.sh" => failing("build error") }).ran?("lint.sh")
  end

  def test_should_not_run_fast_when_lint_fails
    refute runner_after({ "lint.sh" => failing("lint errors") }).ran?("fast.sh")
  end

  def test_should_not_run_fast_when_build_fails
    refute runner_after({ "build.sh" => failing("build error") }).ran?("fast.sh")
  end

  def test_should_run_fast_when_lint_and_build_pass
    assert runner_after.ran?("fast.sh")
  end

  def test_should_start_the_slow_suite_once_phase_one_has_run_and_before_fast
    runner = scripted_runner
    ran_before_slow = nil
    launcher = ->(**) { ran_before_slow = runner.commands.dup }
    slot_run(slot_with(Lock.new(false)), command_runner: runner, background_launcher: launcher).run(config)

    assert_equal %w[build.sh lint.sh], ran_before_slow.map { |cmd| File.basename(cmd.split.first) }.sort
  end

  def test_should_run_the_slow_suite_s_script_with_the_commit_hash
    runner = scripted_runner
    slot_run(slot_with(Lock.new(false)), command_runner: runner, background_launcher: inline_launcher).run(config)

    assert_equal "/slot-0/.fun-ci/slow.sh abc1234", runner.command_for("slow.sh")
  end

  def test_should_fail_when_fast_fails_while_the_slow_suite_runs
    refute_equal 0, run_with({ "fast.sh" => failing("fast test failed") })
  end

  def test_should_fail_when_phase_one_fails
    refute_equal 0, run_with({ "lint.sh" => failing("lint errors") })
  end

  def test_should_pass_when_every_foreground_stage_passes
    assert_equal 0, run_with({})
  end

  private

  def run_with(answers) = slot_run(slot_with(Lock.new(false)), command_runner: scripted_runner(answers)).run(config)

  def runner_after(answers = {})
    runner = scripted_runner(answers)
    slot_run(slot_with(Lock.new(false)), command_runner: runner).run(config)
    runner
  end
end
