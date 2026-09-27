# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/stage_end"

# How a stage that has finished is recorded, whichever process ran it.
class TestStageEnd < Minitest::Test
  Finished = FunCi::Pipeline::StageEnd::Finished

  def test_should_keep_the_exit_status_of_a_stage_that_failed
    calls = recorded(Finished.new(output: "", status: FakeStatus.new(false, 3), timed_out: false, failures: []))

    assert_includes calls, [:keep_exit, 1, 3, nil]
  end

  def test_should_keep_the_signal_that_ended_a_stage
    status = FakeStatus.new(success?: false, exitstatus: nil, termsig: 9)
    calls = recorded(Finished.new(output: "", status: status, timed_out: false, failures: []))

    assert_includes calls, [:keep_exit, 1, nil, "KILL"]
  end

  def test_should_keep_no_exit_for_a_stage_killed_over_budget
    calls = recorded(Finished.new(output: "", status: nil, timed_out: true, failures: []))

    refute(calls.any? { |call| call.first == :keep_exit })
  end

  def test_should_keep_the_exit_before_recording_the_outcome
    calls = recorded(Finished.new(output: "", status: FakeStatus.new(true, 0), timed_out: false, failures: []))

    assert_operator calls.index([:keep_exit, 1, 0, nil]), :<, calls.index([:end_stage, 1, "completed"])
  end

  def test_should_answer_the_outcome_it_recorded
    finished = Finished.new(output: "", status: nil, timed_out: true, failures: [])

    assert_equal "timed_out", FunCi::Pipeline::StageEnd.new(FakeRecorder.new, 1).record(finished)
  end

  private

  def recorded(finished)
    recorder = FakeRecorder.new
    FunCi::Pipeline::StageEnd.new(recorder, 1).record(finished)
    recorder.calls
  end
end
