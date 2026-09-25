# frozen_string_literal: true

require_relative "trigger_cli_shared"

# What `fun-ci trigger <commit> <branch>` accepts and refuses, and the exit
# code a hook gets back.
class TestTriggerCliArguments < Minitest::Test
  NULL_SHA = "0" * 40
  REJECTING = ->(_sha) { false }
  FAST_SUITE_FAILS = lambda { |cmd|
    cmd.include?("fast.sh") ? ["test_foo FAILED", FakeStatus.new(false, 1)] : ["", FakeStatus.new(true, 0)]
  }

  def setup
    @client = TriggerCliClient.open(command_runner: INSTANT_SUCCESS_RUNNER)
  end

  def teardown
    @client.close
  end

  def test_should_pass_a_commit_whose_pipeline_passes
    @client.trigger(commit_hash: "abc1234", branch: "main")

    assert_equal 0, @client.exit_code
  end

  def test_should_refuse_a_commit_the_repository_does_not_have
    @client.trigger(commit_hash: "deadbeef000000", branch: "main", commit_validator: REJECTING)

    refute_equal 0, @client.exit_code
  end

  def test_should_say_the_commit_was_not_found
    @client.trigger(commit_hash: "deadbeef000000", branch: "main", commit_validator: REJECTING)

    assert_includes @client.stderr, "commit deadbeef000000 not found"
  end

  # A root commit's pre-commit hook has no HEAD yet and passes the null SHA.
  def test_should_run_the_pipeline_for_the_null_sha_without_looking_it_up
    @client.trigger(commit_hash: NULL_SHA, branch: "main", commit_validator: REJECTING)

    assert_equal 0, @client.exit_code
  end

  def test_should_fail_when_the_fast_suite_fails
    trigger_with_failing_fast_suite

    refute_equal 0, @client.exit_code
  end

  def test_should_show_the_fast_suite_output_when_it_fails
    trigger_with_failing_fast_suite

    assert_match(/test_foo FAILED/, @client.stdout)
  end

  private

  def trigger_with_failing_fast_suite
    @client.close
    @client = TriggerCliClient.open(command_runner: FAST_SUITE_FAILS)
    @client.trigger(commit_hash: "abc1234", branch: "main")
  end
end
