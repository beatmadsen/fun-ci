# frozen_string_literal: true

require_relative "../test_helper"
require "stringio"
require "fun_ci/trigger"

class TestTriggerNoValidateArgParsing < Minitest::Test
  def test_should_return_zero_immediately_with_no_validate_flag
    forker_calls = []
    fake_forker = ->(commit_hash:, branch:, db_path:) {
      forker_calls << { commit_hash: commit_hash, branch: branch }
    }
    exit_code = FunCi::Trigger.run_from_args(
      ["--no-validate", "abc1234", "main"],
      pipeline_forker: fake_forker
    )
    assert_equal 0, exit_code
  end

  def test_should_call_pipeline_forker_with_commit_and_branch
    forker_calls = []
    fake_forker = ->(commit_hash:, branch:, db_path:) {
      forker_calls << { commit_hash: commit_hash, branch: branch }
    }
    FunCi::Trigger.run_from_args(
      ["--no-validate", "deadbeef", "feature-x"],
      pipeline_forker: fake_forker
    )
    assert_equal 1, forker_calls.length
    assert_equal "deadbeef", forker_calls.first[:commit_hash]
    assert_equal "feature-x", forker_calls.first[:branch]
  end

  def test_should_still_require_commit_and_branch_with_no_validate
    stderr = StringIO.new
    exit_code = FunCi::Trigger.run_from_args(
      ["--no-validate"],
      stderr: stderr
    )
    refute_equal 0, exit_code
    assert_match(/commit/i, stderr.string)
  end

  def test_should_reject_no_validate_with_only_one_positional_arg
    stderr = StringIO.new
    exit_code = FunCi::Trigger.run_from_args(
      ["--no-validate", "abc1234"],
      stderr: stderr
    )
    refute_equal 0, exit_code
  end

  def test_should_handle_no_validate_flag_in_any_position
    forker_calls = []
    fake_forker = ->(commit_hash:, branch:, db_path:) {
      forker_calls << { commit_hash: commit_hash, branch: branch }
    }
    FunCi::Trigger.run_from_args(
      ["abc1234", "--no-validate", "main"],
      pipeline_forker: fake_forker
    )
    assert_equal "abc1234", forker_calls.first[:commit_hash]
    assert_equal "main", forker_calls.first[:branch]
  end

  def test_should_pass_db_path_from_recorder_to_forker
    forker_calls = []
    fake_forker = ->(commit_hash:, branch:, db_path:) {
      forker_calls << { db_path: db_path }
    }
    recorder = FakeRecorder.new
    FunCi::Trigger.run_from_args(
      ["--no-validate", "abc1234", "main"],
      recorder: recorder,
      pipeline_forker: fake_forker
    )
    assert_nil forker_calls.first[:db_path]
  end

  def test_should_close_recorder_before_calling_forker
    close_called_before_fork = nil
    closed = false

    recorder = FakeRecorder.new
    recorder.define_singleton_method(:close) { closed = true }

    forker = ->(commit_hash:, branch:, db_path:) {
      close_called_before_fork = closed
    }

    FunCi::Trigger.run_from_args(
      ["--no-validate", "abc1234", "main"],
      recorder: recorder,
      pipeline_forker: forker
    )

    assert close_called_before_fork,
      "Recorder should be closed before the forker is called"
  end

  def test_should_not_invoke_forker_without_no_validate_flag
    forker_calls = []
    fake_forker = ->(commit_hash:, branch:, db_path:) {
      forker_calls << true
    }
    FunCi::Trigger.run_from_args(
      ["abc1234", "main"],
      pipeline_forker: fake_forker,
      stderr: StringIO.new
    )
    assert_empty forker_calls
  end
end
