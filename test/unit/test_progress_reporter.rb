# frozen_string_literal: true

require_relative "../test_helper"
require "stringio"
require "fun_ci/pipeline/progress_reporter"

class TestProgressReporterPhaseOne < Minitest::Test
  def test_should_show_lint_and_build_passed_when_phase_one_succeeds
    # Given a progress reporter writing to a captured stdout
    stdout = StringIO.new
    reporter = FunCi::Pipeline::ProgressReporter.new(stdout: stdout)
    # When phase one passes with both lint and build ok
    reporter.phase_one_result({ "lint" => true, "build" => true })
    # Then stdout should show both stages passed and the phase summary
    assert_match(/lint ok/, stdout.string, "Should show lint ok")
    assert_match(/build ok/, stdout.string, "Should show build ok")
    assert_match(/phase 1 passed/i, stdout.string, "Should summarize phase 1 passed")
  end

  def test_should_show_failed_stages_when_phase_one_fails
    # Given a progress reporter
    stdout = StringIO.new
    reporter = FunCi::Pipeline::ProgressReporter.new(stdout: stdout)
    # When lint fails but build passes
    reporter.phase_one_result({ "lint" => false, "build" => true })
    # Then stdout should show lint FAIL and phase 1 failed
    assert_match(/lint FAIL/, stdout.string, "Should show lint FAIL")
    assert_match(/build ok/, stdout.string, "Should show build ok")
    assert_match(/phase 1 failed/i, stdout.string, "Should summarize phase 1 failed")
  end
end

class TestProgressReporterPhaseTwo < Minitest::Test
  def test_should_show_fast_ok_when_fast_suite_passes
    # Given a progress reporter
    stdout = StringIO.new
    reporter = FunCi::Pipeline::ProgressReporter.new(stdout: stdout)
    # When fast suite passes
    reporter.fast_result(true)
    # Then stdout should show fast ok
    assert_match(/fast ok/, stdout.string, "Should show fast ok")
  end

  def test_should_show_fast_fail_when_fast_suite_fails
    # Given a progress reporter
    stdout = StringIO.new
    reporter = FunCi::Pipeline::ProgressReporter.new(stdout: stdout)
    # When fast suite fails
    reporter.fast_result(false)
    # Then stdout should show fast FAIL
    assert_match(/fast FAIL/, stdout.string, "Should show fast FAIL")
  end

  def test_should_show_slow_running_in_background
    # Given a progress reporter
    stdout = StringIO.new
    reporter = FunCi::Pipeline::ProgressReporter.new(stdout: stdout)
    # When slow suite is launched
    reporter.slow_launched
    # Then stdout should indicate it is running in background
    assert_match(/slow.*background/i, stdout.string, "Should indicate slow runs in background")
  end
end
