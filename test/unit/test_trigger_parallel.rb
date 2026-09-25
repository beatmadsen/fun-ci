# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/trigger_test_kit"

# Phase 1 runs lint and build side by side and both must pass. Phase 2 starts
# the slow suite in the background, then runs the fast suite.
class TestTriggerParallelPhaseOne < Minitest::Test
  include FunCiTestProject
  include TriggerTestKit

  def test_should_run_build_even_when_lint_fails
    assert runner_after("lint.sh" => failing("lint errors")).ran?("build.sh")
  end

  def test_should_run_lint_even_when_build_fails
    assert runner_after("build.sh" => failing("build error")).ran?("lint.sh")
  end

  def test_should_not_run_fast_when_lint_fails_in_phase_one
    refute runner_after("lint.sh" => failing("lint errors")).ran?("fast.sh")
  end

  def test_should_not_run_fast_when_build_fails_in_phase_one
    refute runner_after("build.sh" => failing("build error")).ran?("fast.sh")
  end

  def test_should_proceed_to_fast_when_both_lint_and_build_pass
    assert runner_after.ran?("fast.sh")
  end

  def test_should_report_the_lint_failure_when_lint_and_build_both_fail
    assert_includes both_failing.stdout, "Lint failed."
  end

  def test_should_report_the_build_failure_when_lint_and_build_both_fail
    assert_includes both_failing.stdout, "Build failed."
  end

  private

  def both_failing
    run_in_project(command_runner: scripted_runner({ "lint.sh" => failing("lint errors"),
                                                     "build.sh" => failing("build errors") }))
  end

  def runner_after(answers = {})
    runner = scripted_runner(answers)
    in_project { |dir| build_trigger(dir, command_runner: runner).run }
    runner
  end
end

class TestTriggerParallelPhaseTwo < Minitest::Test
  include FunCiTestProject
  include TriggerTestKit

  def test_should_spawn_slow_when_only_the_phase_one_stages_have_run
    runner = scripted_runner
    launcher = ->(**) { @ran_before_spawn = runner.commands.dup }
    in_project { |dir| build_trigger(dir, command_runner: runner, background_launcher: launcher).run }

    assert_equal 2, @ran_before_spawn.size
  end

  def test_should_fail_when_fast_fails_even_with_parallel_slow
    outcome = run_in_project(command_runner: scripted_runner({ "fast.sh" => failing("fast test failed") }))

    refute_equal 0, outcome.exit_code
  end
end
