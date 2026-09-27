# frozen_string_literal: true

require_relative "../test_helper"
require "stringio"
require "fun_ci/pipeline/stage_runner"
require_relative "../support/fake_report_dir"

# A stage that fails or overruns has its output kept before its outcome is
# recorded, so anyone who sees the outcome can read why (AT-9.5).
class TestStageRunnerOutput < Minitest::Test
  Config = Data.define(:dir) do
    def script_path(stage) = "#{stage}.sh"
  end

  def test_keeps_the_output_of_a_stage_that_failed_before_recording_its_outcome
    calls = recorded(->(_cmd) { ["boom\n", FakeStatus.new(false, 1)] })

    assert_operator calls.index([:keep_output, 1, "boom\n"]), :<, calls.index([:end_stage, 1, "failed"])
  end

  def test_keeps_the_output_of_a_stage_that_ran_over_budget
    calls = recorded(->(_cmd) { raise Timeout::Error })

    assert_includes calls, [:keep_output, 1, ""]
  end

  def test_keeps_nothing_of_a_stage_that_passed
    calls = recorded(->(_cmd) { ["fine\n", FakeStatus.new(true, 0)] })

    refute(calls.any? { |call| call.first == :keep_output })
  end

  def test_keeps_the_failures_a_failed_stage_reported
    reports = FakeReportDir.new([{ test: "t1" }])
    calls = recorded(->(_cmd) { ["boom\n", FakeStatus.new(false, 1)] }, reports)

    assert_includes calls, [:keep_failures, 1, [{ test: "t1" }]]
  end

  def test_names_the_report_directory_to_the_stage
    seen = nil
    recorded(->(_cmd, env) { (seen = env) && ["", FakeStatus.new(true, 0)] }, FakeReportDir.new([]))

    assert_equal({ "FUN_CI_REPORT" => "/fake/reports" }, seen)
  end

  def test_removes_the_report_directory_after_the_stage
    reports = FakeReportDir.new([])
    recorded(->(_cmd) { ["", FakeStatus.new(true, 0)] }, reports)

    assert reports.removed
  end

  private

  def recorded(runner, reports = FakeReportDir.new([]))
    recorder = FakeRecorder.new
    seams = FunCi::Pipeline::Seams.new(command_runner: runner, recorder: recorder, report_dir: -> { reports })
    FunCi::Pipeline::StageRunner.new(commit_hash: "abc123", stdout: StringIO.new, seams: seams)
                                .passes?(Config.new(dir: "/p"), "fast")
    recorder.calls
  end
end

# A stage starts with its budget recorded, which `fun-ci why` reads back (AT-10.1).
class TestStageRunnerBudget < Minitest::Test
  Config = Data.define(:dir) do
    def script_path(stage) = "#{stage}.sh"
  end

  def test_should_record_the_budget_a_stage_starts_with
    recorder = FakeRecorder.new
    seams = FunCi::Pipeline::Seams.new(command_runner: ->(_cmd) { ["", FakeStatus.new(true, 0)] }, recorder: recorder,
                                       report_dir: -> { FakeReportDir.new([]) }, time_budgets: { "fast" => 7 })
    FunCi::Pipeline::StageRunner.new(commit_hash: "abc123", stdout: StringIO.new, seams: seams)
                                .passes?(Config.new(dir: "/p"), "fast")

    assert_equal({ "fast" => 7 }, recorder.budgets)
  end
end
