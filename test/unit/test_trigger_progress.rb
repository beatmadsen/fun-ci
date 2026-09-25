# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/trigger_test_kit"

# The trigger reports each phase's result as it completes, so a git hook user
# sees progress.
class TestTriggerProgress < Minitest::Test
  include FunCiTestProject
  include TriggerTestKit

  def test_should_show_phase_one_passed_when_lint_and_build_succeed
    assert_match(/lint ok  build ok  \(phase 1 passed\)|build ok  lint ok  \(phase 1 passed\)/, progress)
  end

  def test_should_show_fast_ok_when_all_pass
    assert_match(/fast ok/, progress)
  end

  def test_should_say_the_slow_suite_runs_in_the_background
    assert_match(/slow \(running in background\)/, progress)
  end

  def test_should_show_phase_one_failed_when_lint_fails
    assert_match(/lint FAIL.*\(phase 1 failed\)/, progress("lint.sh" => failing("lint errors")))
  end

  def test_should_show_fast_fail_when_fast_suite_fails
    assert_match(/fast FAIL/, progress("fast.sh" => failing("test failures")))
  end

  private

  def progress(answers = {})
    io = quiet_io
    in_project { |dir| build_trigger(dir, io: io, command_runner: scripted_runner(answers)).run }
    io.stdout.string
  end
end
