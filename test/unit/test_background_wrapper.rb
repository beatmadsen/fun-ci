# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/background_wrapper"

class TestBackgroundWrapperEndStage < Minitest::Test
  SUCCESS = ["", FakeStatus.new(true, 0), false].freeze
  FAILURE = ["test failed", FakeStatus.new(false, 1), false].freeze
  TIMEOUT = ["", nil, true].freeze

  def test_should_call_end_stage_with_completed_when_command_exits_zero
    end_stage_calls = calls_after(SUCCESS, :end_stage)
    assert_equal 1, end_stage_calls.size, "Should call end_stage exactly once"
    assert_equal [1, "completed"], end_stage_calls.first[1..],
                 "Should call end_stage with job_id and 'completed'"
  end

  def test_should_call_end_stage_with_failed_when_command_exits_nonzero
    end_stage_calls = calls_after(FAILURE, :end_stage)
    assert_equal 1, end_stage_calls.size, "Should call end_stage exactly once"
    assert_equal [1, "failed"], end_stage_calls.first[1..],
                 "Should call end_stage with job_id and 'failed'"
  end

  def test_should_call_end_stage_with_timed_out_when_executor_signals_timeout
    end_stage_calls = calls_after(TIMEOUT, :end_stage)
    assert_equal 1, end_stage_calls.size, "Should call end_stage exactly once"
    assert_equal [1, "timed_out"], end_stage_calls.first[1..],
                 "Should call end_stage with job_id and 'timed_out'"
  end

  def test_should_record_the_process_the_slow_suite_runs_in
    recorder = FakeRecorder.new
    executor = lambda do |&on_start|
      on_start.call(4242)
      SUCCESS
    end
    FunCi::Pipeline::BackgroundWrapper.new(recorder: recorder, job_id: 1, executor: executor).run

    assert_includes recorder.calls, [:stage_process, 1, 4242]
  end

  private

  def calls_after(outcome, method_name)
    recorder = FakeRecorder.new
    FunCi::Pipeline::BackgroundWrapper.new(recorder: recorder, job_id: 1, executor: -> { outcome }).run
    recorder.calls.select { |c| c[0] == method_name }
  end
end
