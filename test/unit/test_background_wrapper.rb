# frozen_string_literal: true

require_relative "../test_helper"
require "timeout"
require "fun_ci/background_wrapper"

class TestBackgroundWrapperEndStage < Minitest::Test
  def test_should_call_end_stage_with_completed_when_command_exits_zero
    # Given an executor that returns success and a fake recorder
    recorder = FakeRecorder.new
    executor = -> { ["", FakeStatus.new(true, 0)] }
    wrapper = FunCi::BackgroundWrapper.new(
      recorder: recorder,
      job_id: 1,
      executor: executor
    )
    # When the wrapper runs
    wrapper.run
    # Then recorder should have received end_stage with "completed"
    end_stage_calls = recorder.calls.select { |c| c[0] == :end_stage }
    assert_equal 1, end_stage_calls.size, "Should call end_stage exactly once"
    assert_equal [1, "completed"], end_stage_calls.first[1..],
      "Should call end_stage with job_id and 'completed'"
  end

  def test_should_call_complete_run_after_successful_slow_stage
    # Given an executor that returns success and a fake recorder
    recorder = FakeRecorder.new
    executor = -> { ["", FakeStatus.new(true, 0)] }
    wrapper = FunCi::BackgroundWrapper.new(
      recorder: recorder,
      job_id: 1,
      executor: executor
    )
    # When the wrapper runs
    wrapper.run
    # Then recorder should have received complete_run
    complete_calls = recorder.calls.select { |c| c[0] == :complete_run }
    assert_equal 1, complete_calls.size,
      "Should call complete_run after successful slow stage"
  end

  def test_should_call_end_stage_with_failed_when_command_exits_nonzero
    # Given an executor that returns failure and a fake recorder
    recorder = FakeRecorder.new
    executor = -> { ["test failed", FakeStatus.new(false, 1)] }
    wrapper = FunCi::BackgroundWrapper.new(
      recorder: recorder,
      job_id: 1,
      executor: executor
    )
    # When the wrapper runs
    wrapper.run
    # Then recorder should have received end_stage with "failed"
    end_stage_calls = recorder.calls.select { |c| c[0] == :end_stage }
    assert_equal 1, end_stage_calls.size, "Should call end_stage exactly once"
    assert_equal [1, "failed"], end_stage_calls.first[1..],
      "Should call end_stage with job_id and 'failed'"
  end

  def test_should_call_fail_run_after_failed_slow_stage
    # Given an executor that returns failure and a fake recorder
    recorder = FakeRecorder.new
    executor = -> { ["test failed", FakeStatus.new(false, 1)] }
    wrapper = FunCi::BackgroundWrapper.new(
      recorder: recorder,
      job_id: 1,
      executor: executor
    )
    # When the wrapper runs
    wrapper.run
    # Then recorder should have received fail_run
    fail_calls = recorder.calls.select { |c| c[0] == :fail_run }
    assert_equal 1, fail_calls.size,
      "Should call fail_run after failed slow stage"
  end

  def test_should_call_end_stage_with_timed_out_when_executor_raises_timeout
    # Given an executor that raises Timeout::Error and a fake recorder
    recorder = FakeRecorder.new
    executor = -> { raise Timeout::Error, "simulated timeout" }
    wrapper = FunCi::BackgroundWrapper.new(
      recorder: recorder,
      job_id: 1,
      executor: executor
    )
    # When the wrapper runs
    wrapper.run
    # Then recorder should have received end_stage with "timed_out"
    end_stage_calls = recorder.calls.select { |c| c[0] == :end_stage }
    assert_equal 1, end_stage_calls.size, "Should call end_stage exactly once"
    assert_equal [1, "timed_out"], end_stage_calls.first[1..],
      "Should call end_stage with job_id and 'timed_out'"
  end

  def test_should_call_fail_run_after_timed_out_slow_stage
    # Given an executor that raises Timeout::Error and a fake recorder
    recorder = FakeRecorder.new
    executor = -> { raise Timeout::Error, "simulated timeout" }
    wrapper = FunCi::BackgroundWrapper.new(
      recorder: recorder,
      job_id: 1,
      executor: executor
    )
    # When the wrapper runs
    wrapper.run
    # Then recorder should have received fail_run
    fail_calls = recorder.calls.select { |c| c[0] == :fail_run }
    assert_equal 1, fail_calls.size,
      "Should call fail_run after timed out slow stage"
  end
end
