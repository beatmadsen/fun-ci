# frozen_string_literal: true

require_relative "../test_helper"
require "stringio"
require "fun_ci/pipeline/trigger"

class TestTriggerNoValidateArgParsing < Minitest::Test
  def setup
    @forker_calls = []
    @forker = ->(**call) { @forker_calls << call }
  end

  def test_should_return_zero_immediately_with_no_validate_flag
    assert_equal 0, run_trigger(["--no-validate", "abc1234", "main"])
  end

  def test_should_call_pipeline_forker_with_commit_and_branch
    run_trigger(["--no-validate", "deadbeef", "feature-x"])
    assert_equal 1, @forker_calls.length
    assert_equal "deadbeef", @forker_calls.first[:commit_hash]
    assert_equal "feature-x", @forker_calls.first[:branch]
  end

  def test_should_still_require_commit_and_branch_with_no_validate
    stderr = StringIO.new
    exit_code = FunCi::Pipeline::Trigger.run_from_args(["--no-validate"], io: FunCi::Pipeline::Io.new(stderr: stderr))
    refute_equal 0, exit_code
    assert_match(/commit/i, stderr.string)
  end

  def test_should_reject_no_validate_with_only_one_positional_arg
    exit_code = FunCi::Pipeline::Trigger.run_from_args(["--no-validate", "abc1234"], io: quiet_io)
    refute_equal 0, exit_code
  end

  def test_should_handle_no_validate_flag_in_any_position
    run_trigger(["abc1234", "--no-validate", "main"])
    assert_equal "abc1234", @forker_calls.first[:commit_hash]
    assert_equal "main", @forker_calls.first[:branch]
  end

  def test_should_pass_db_path_from_recorder_to_forker
    recorder = FakeRecorder.new
    recorder.define_singleton_method(:db_path) { "/tmp/pipelines.sqlite3" }
    run_trigger(["--no-validate", "abc1234", "main"], recorder: recorder)
    assert_equal "/tmp/pipelines.sqlite3", @forker_calls.first[:db_path]
  end

  def test_should_close_recorder_before_calling_forker
    closed = false
    recorder = FakeRecorder.new
    recorder.define_singleton_method(:close) { closed = true }
    @forker = ->(**) { @forker_calls << closed }
    run_trigger(["--no-validate", "abc1234", "main"], recorder: recorder)
    assert @forker_calls.first, "Recorder should be closed before the forker is called"
  end

  def test_should_not_invoke_forker_without_no_validate_flag
    run_trigger(%w[abc1234 main])
    assert_empty @forker_calls
  end

  private

  def run_trigger(args, recorder: FakeRecorder.new)
    FunCi::Pipeline::Trigger.run_from_args(args, io: quiet_io, recorder: recorder, pipeline_forker: @forker)
  end

  def quiet_io = FunCi::Pipeline::Io.new(stdout: StringIO.new, stderr: StringIO.new)
end
