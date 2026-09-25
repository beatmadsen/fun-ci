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

  def test_should_call_complete_run_after_successful_slow_stage
    assert_equal 1, calls_after(SUCCESS, :complete_run).size,
                 "Should call complete_run after successful slow stage"
  end

  def test_should_call_end_stage_with_failed_when_command_exits_nonzero
    end_stage_calls = calls_after(FAILURE, :end_stage)
    assert_equal 1, end_stage_calls.size, "Should call end_stage exactly once"
    assert_equal [1, "failed"], end_stage_calls.first[1..],
                 "Should call end_stage with job_id and 'failed'"
  end

  def test_should_call_fail_run_after_failed_slow_stage
    assert_equal 1, calls_after(FAILURE, :fail_run).size,
                 "Should call fail_run after failed slow stage"
  end

  def test_should_call_end_stage_with_timed_out_when_executor_signals_timeout
    end_stage_calls = calls_after(TIMEOUT, :end_stage)
    assert_equal 1, end_stage_calls.size, "Should call end_stage exactly once"
    assert_equal [1, "timed_out"], end_stage_calls.first[1..],
                 "Should call end_stage with job_id and 'timed_out'"
  end

  def test_should_call_fail_run_after_timed_out_slow_stage
    assert_equal 1, calls_after(TIMEOUT, :fail_run).size,
                 "Should call fail_run after timed out slow stage"
  end

  private

  def calls_after(outcome, method_name)
    recorder = FakeRecorder.new
    FunCi::Pipeline::BackgroundWrapper.new(recorder: recorder, job_id: 1, executor: -> { outcome }).run
    recorder.calls.select { |c| c[0] == method_name }
  end
end
