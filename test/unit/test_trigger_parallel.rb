# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/trigger_test_kit"

# Phase 1 runs lint and build side by side and both must pass. Phase 2 starts
# the slow suite in the background, then runs the fast suite.
class TestTriggerParallelPhaseOne < Minitest::Test
  include FunCiTestProject
  include TriggerTestKit

  def test_should_run_build_even_when_lint_fails
    assert(commands_run("lint.sh" => failing("lint errors")).any? { |cmd| cmd.include?("build.sh") })
  end

  def test_should_run_lint_even_when_build_fails
    assert(commands_run("build.sh" => failing("build error")).any? { |cmd| cmd.include?("lint.sh") })
  end

  def test_should_not_run_fast_when_lint_fails_in_phase_one
    refute(commands_run("lint.sh" => failing("lint errors")).any? { |cmd| cmd.include?("fast.sh") })
  end

  def test_should_not_run_fast_when_build_fails_in_phase_one
    refute(commands_run("build.sh" => failing("build error")).any? { |cmd| cmd.include?("fast.sh") })
  end

  def test_should_proceed_to_fast_when_both_lint_and_build_pass
    assert(commands_run.any? { |cmd| cmd.include?("fast.sh") })
  end

  def test_should_report_both_failures_when_lint_and_build_both_fail
    io = quiet_io
    runner = scripted_runner({ "lint.sh" => failing("lint errors"), "build.sh" => failing("build errors") })
    in_project { |dir| build_trigger(dir, io: io, command_runner: runner).run }

    assert_match(/Lint failed.*Build failed|Build failed.*Lint failed/m, io.stdout.string)
  end

  private

  def commands_run(answers = {})
    log = []
    in_project { |dir| build_trigger(dir, command_runner: scripted_runner(answers, log: log)).run }
    log
  end
end

class TestTriggerParallelPhaseTwo < Minitest::Test
  include FunCiTestProject
  include TriggerTestKit

  def test_should_spawn_slow_before_fast_runs
    events = []
    seams = { command_runner: scripted_runner(log: events), background_launcher: ->(**) { events << :spawn_slow } }
    in_project { |dir| build_trigger(dir, **seams).run }
    fast = events.index { |event| event.to_s.include?("fast.sh") }

    assert_operator events.index(:spawn_slow), :<, fast
  end

  def test_should_fail_when_fast_fails_even_with_parallel_slow
    exit_code = in_project do |dir|
      build_trigger(dir, command_runner: scripted_runner({ "fast.sh" => failing("fast test failed") })).run
    end

    refute_equal 0, exit_code
  end
end
