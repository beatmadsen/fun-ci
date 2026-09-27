# frozen_string_literal: true

require_relative "../test_helper"
require "stringio"
require "fun_ci/pipeline/stage_runner"

# A stage that fails or overruns has its output kept before its outcome is
# recorded, so anyone who sees the outcome can read why (AT-9.5).
class TestStageRunnerOutput < Minitest::Test
  Config = Data.define(:dir) do
    def script_path(stage) = "#{stage}.sh"
  end

  def test_keeps_the_output_of_a_stage_that_failed_before_recording_its_outcome
    calls = recorded(->(_cmd) { ["boom\n", FakeStatus.new(false, 1)] })

    assert_equal [[:keep_output, 1, "boom\n"], [:end_stage, 1, "failed"]], calls.last(2)
  end

  def test_keeps_the_output_of_a_stage_that_ran_over_budget
    calls = recorded(->(_cmd) { raise Timeout::Error })

    assert_includes calls, [:keep_output, 1, ""]
  end

  def test_keeps_nothing_of_a_stage_that_passed
    calls = recorded(->(_cmd) { ["fine\n", FakeStatus.new(true, 0)] })

    refute(calls.any? { |call| call.first == :keep_output })
  end

  private

  def recorded(runner)
    recorder = FakeRecorder.new
    seams = FunCi::Pipeline::Seams.new(command_runner: runner, recorder: recorder)
    FunCi::Pipeline::StageRunner.new(commit_hash: "abc123", stdout: StringIO.new, seams: seams)
                                .passes?(Config.new(dir: "/p"), "fast")
    recorder.calls
  end
end
