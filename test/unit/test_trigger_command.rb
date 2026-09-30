# frozen_string_literal: true

require_relative "../test_helper"
require "stringio"
require "fun_ci/pipeline/trigger"

# `fun-ci trigger [--background] <commit-hash> <branch>`: what it accepts,
# and handing a --background run to the forker. --no-validate is the 1.x
# name for --background, kept for one release.
class TestTriggerCommand < Minitest::Test
  USAGE = "fun-ci: commit hash and branch name are required.\nUsage: fun-ci trigger <commit-hash> <branch>\n"

  FORKED = FunCi::Pipeline::PipelineForker::Forked.new(notice: nil)

  def setup
    @forker_calls = []
    @forker = ->(**call) { @forker_calls.push(call).then { FORKED } }
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

  def test_should_fail_with_only_background
    refute_equal 0, run_command(["--background"])
  end

  def test_should_fail_with_background_and_only_a_commit_hash
    refute_equal 0, run_command(["--background", "abc1234"])
  end

  def test_should_return_at_once_when_background_hands_the_run_to_the_forker
    assert_equal 0, run_command(["--background", "abc1234", "main"])
  end

  def test_should_hand_the_forker_the_commit_and_branch
    run_command(["--background", "deadbeef", "feature-x"])

    assert_equal [%w[deadbeef feature-x]], forked_commits
  end

  def test_should_accept_background_in_any_position
    run_command(["abc1234", "--background", "main"])

    assert_equal [%w[abc1234 main]], forked_commits
  end

  def test_should_hand_the_forker_the_database_path
    recorder = FakeRecorder.new
    recorder.define_singleton_method(:db_path) { "/tmp/pipelines.sqlite3" }
    run_command(["--background", "abc1234", "main"], recorder: recorder)

    assert_equal "/tmp/pipelines.sqlite3", @forker_calls.first[:db_path]
  end

  def test_should_close_its_database_connection_before_forking
    closed = false
    recorder = FakeRecorder.new
    recorder.define_singleton_method(:close) { closed = true }
    @forker = ->(**) { @forker_calls.push(closed).then { FORKED } }
    run_command(["--background", "abc1234", "main"], recorder: recorder)

    assert @forker_calls.first
  end

  def test_should_treat_no_validate_as_background
    run_command(["--no-validate", "abc1234", "main"])

    assert_equal [%w[abc1234 main]], forked_commits
  end

  def test_should_say_no_validate_is_deprecated_in_one_line
    run_command(["--no-validate", "abc1234", "main"])

    assert_equal "fun-ci: --no-validate is now --background; the old name goes in 3.0.\n", @stderr.string
  end

  def test_should_say_nothing_on_stderr_for_background
    run_command(["--background", "abc1234", "main"])

    assert_empty @stderr.string
  end

  def test_should_say_how_to_get_the_verdict_of_the_run_it_started
    run_command(["--background", "3f9c2ab0c4d1e2f3", "main"])

    assert_equal "fun-ci: testing 3f9c2ab. Verdict: fun-ci wait 3f9c2ab --need all\n", @stdout.string
  end

  def test_should_say_what_the_forker_says_of_a_first_fetch_after_how_to_get_the_verdict
    @forker = ->(**) { FORKED.with(notice: "fun-ci: fetching origin/main") }
    run_command(["--background", "3f9c2ab0c4d1e2f3", "main"])

    assert_equal "fun-ci: testing 3f9c2ab. Verdict: fun-ci wait 3f9c2ab --need all\nfun-ci: fetching origin/main\n",
                 @stdout.string
  end

  def test_should_say_nothing_when_the_forker_started_no_run
    @forker = ->(**) { false }
    run_command(["--background", "3f9c2ab0c4d1e2f3", "main"])

    assert_empty @stdout.string
  end

  # The project has no .fun-ci/, so the foreground run ends before any stage.
  def test_should_not_fork_without_background
    run_command(%w[abc1234 main])

    assert_empty @forker_calls
  end

  private

  def run_command(args, recorder: FakeRecorder.new)
    @stderr = StringIO.new
    @stdout = StringIO.new
    io = FunCi::Pipeline::Io.new(stdout: @stdout, stderr: @stderr)
    FunCi::Pipeline::TriggerCommand.new(io: io, recorder: recorder, pipeline_forker: @forker,
                                        project: "/no/such/project").run(args)
  end

  def forked_commits = @forker_calls.map { |call| call.values_at(:commit_hash, :branch) }
end
