# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/stage_end"

# How a stage that has finished is recorded, whichever process ran it.
class TestStageEnd < Minitest::Test
  Finished = FunCi::Pipeline::StageEnd::Finished

  # Answers what it was given to collect from, so a test can see it was asked.
  class EchoCollector
    def collect(output, alongside: []) = "evidence of #{output}#{alongside.map { |stage| " beside #{stage}" }.join}"
    def masked(output) = "masked #{output}"
  end

  def test_should_keep_the_evidence_of_a_stage_that_failed_before_recording_its_outcome
    calls = recorded(Finished.new(output: "boom", status: FakeStatus.new(false, 1), timed_out: false))

    assert_operator calls.index([:keep_evidence, 1, "evidence of boom"]), :<, calls.index([:end_stage, 1, "failed"])
  end

  def test_should_keep_the_evidence_of_a_stage_that_ran_over_budget
    calls = recorded(Finished.new(output: "partial", status: nil, timed_out: true))

    assert_includes calls, [:keep_evidence, 1, "evidence of partial"]
  end

  def test_should_keep_the_masked_raw_output_of_a_stage_that_failed
    calls = recorded(Finished.new(output: "boom", status: FakeStatus.new(false, 1), timed_out: false))

    assert_includes calls, [:keep_raw, 1, "masked boom"]
  end

  def test_should_tell_the_collector_which_stages_shared_the_slot
    recorder = FakeRecorder.new(alongside: %w[slow])
    FunCi::Pipeline::StageEnd.new(recorder, 1, EchoCollector.new)
                             .record(Finished.new(output: "boom", status: FakeStatus.new(false, 1), timed_out: false))

    assert_equal ["evidence of boom beside slow"], recorder.kept_evidence
  end

  def test_should_keep_no_evidence_of_a_stage_that_passed
    calls = recorded(Finished.new(output: "fine", status: FakeStatus.new(true, 0), timed_out: false))

    refute(calls.any? { |call| call.first == :keep_evidence })
  end

  def test_should_keep_the_exit_status_of_a_stage_that_failed
    calls = recorded(Finished.new(output: "", status: FakeStatus.new(false, 3), timed_out: false))

    assert_includes calls, [:keep_exit, 1, 3, nil]
  end

  def test_should_keep_the_signal_that_ended_a_stage
    status = FakeStatus.new(success?: false, exitstatus: nil, termsig: 9)
    calls = recorded(Finished.new(output: "", status: status, timed_out: false))

    assert_includes calls, [:keep_exit, 1, nil, "KILL"]
  end

  def test_should_keep_no_exit_for_a_stage_killed_over_budget
    calls = recorded(Finished.new(output: "", status: nil, timed_out: true))

    refute(calls.any? { |call| call.first == :keep_exit })
  end

  def test_should_keep_the_exit_before_recording_the_outcome
    calls = recorded(Finished.new(output: "", status: FakeStatus.new(true, 0), timed_out: false))

    assert_operator calls.index([:keep_exit, 1, 0, nil]), :<, calls.index([:end_stage, 1, "completed"])
  end

  def test_should_answer_the_outcome_it_recorded
    finished = Finished.new(output: "", status: nil, timed_out: true)

    assert_equal "timed_out", FunCi::Pipeline::StageEnd.new(FakeRecorder.new, 1, EchoCollector.new).record(finished)
  end

  private

  def recorded(finished)
    recorder = FakeRecorder.new
    FunCi::Pipeline::StageEnd.new(recorder, 1, EchoCollector.new).record(finished)
    recorder.calls
  end
end
