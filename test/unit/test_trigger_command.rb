# frozen_string_literal: true

require_relative "../test_helper"
require "stringio"
require "fun_ci/pipeline/trigger"

# `fun-ci trigger [--no-validate] <commit-hash> <branch>`: what it accepts,
# and handing a --no-validate run to the forker.
class TestTriggerCommand < Minitest::Test
  USAGE = "fun-ci: commit hash and branch name are required.\nUsage: fun-ci trigger <commit-hash> <branch>\n"

  def setup
    @forker_calls = []
    @forker = ->(**call) { @forker_calls << call }
  end

  def test_should_fail_without_arguments
    refute_equal 0, run_command([])
  end

  def test_should_print_what_is_required_and_the_usage_when_arguments_are_missing
    run_command([])

    assert_equal USAGE, @stderr.string
  end

  def test_should_fail_with_only_a_commit_hash
    refute_equal 0, run_command(["abc1234"])
  end

  def test_should_fail_with_only_no_validate
    refute_equal 0, run_command(["--no-validate"])
  end

  def test_should_fail_with_no_validate_and_only_a_commit_hash
    refute_equal 0, run_command(["--no-validate", "abc1234"])
  end

  def test_should_return_at_once_when_no_validate_hands_the_run_to_the_forker
    assert_equal 0, run_command(["--no-validate", "abc1234", "main"])
  end

  def test_should_hand_the_forker_the_commit_and_branch
    run_command(["--no-validate", "deadbeef", "feature-x"])

    assert_equal [%w[deadbeef feature-x]], forked_commits
  end

  def test_should_accept_no_validate_in_any_position
    run_command(["abc1234", "--no-validate", "main"])

    assert_equal [%w[abc1234 main]], forked_commits
  end

  def test_should_hand_the_forker_the_database_path
    recorder = FakeRecorder.new
    recorder.define_singleton_method(:db_path) { "/tmp/pipelines.sqlite3" }
    run_command(["--no-validate", "abc1234", "main"], recorder: recorder)

    assert_equal "/tmp/pipelines.sqlite3", @forker_calls.first[:db_path]
  end

  def test_should_close_its_database_connection_before_forking
    closed = false
    recorder = FakeRecorder.new
    recorder.define_singleton_method(:close) { closed = true }
    @forker = ->(**) { @forker_calls << closed }
    run_command(["--no-validate", "abc1234", "main"], recorder: recorder)

    assert @forker_calls.first
  end

  # The project has no .fun-ci/, so the foreground run ends before any stage.
  def test_should_not_fork_without_no_validate
    run_command(%w[abc1234 main])

    assert_empty @forker_calls
  end

  private

  def run_command(args, recorder: FakeRecorder.new)
    @stderr = StringIO.new
    io = FunCi::Pipeline::Io.new(stdout: StringIO.new, stderr: @stderr)
    FunCi::Pipeline::TriggerCommand.new(io: io, recorder: recorder, pipeline_forker: @forker,
                                        project: "/no/such/project").run(args)
  end

  def forked_commits = @forker_calls.map { |call| call.values_at(:commit_hash, :branch) }
end
