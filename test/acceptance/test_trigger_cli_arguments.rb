# frozen_string_literal: true

require_relative "trigger_cli_shared"

# Acceptance tests for CLI invocation and argument handling.
#
# Covers: valid/invalid arguments, commit validation,
# and basic fast suite pass/fail exit codes.

class TestTriggerCliHappyPath < Minitest::Test
  FAST_SUITE_FAILS = lambda { |cmd|
    cmd.include?("fast.sh") ? ["test_foo FAILED", FakeStatus.new(false, 1)] : ["", FakeStatus.new(true, 0)]
  }

  def setup
    @client = TriggerCliClient.open(command_runner: INSTANT_SUCCESS_RUNNER)
  end

  def teardown
    @client.close
  end

  def test_should_accept_commit_hash_and_branch_name
    @client.trigger(commit_hash: "abc1234", branch: "main")
    assert_equal 0, @client.exit_code, "Should accept valid commit and branch"
  end

  def test_should_reject_invocation_when_commit_hash_is_missing
    @client.trigger_raw(args: ["main"])
    refute_equal 0, @client.exit_code, "Should reject missing commit hash"
    assert_match(/commit/i, @client.stderr, "Should mention missing commit")
  end

  def test_should_reject_invocation_when_branch_name_is_missing
    @client.trigger_raw(args: ["abc1234"])
    refute_equal 0, @client.exit_code, "Should reject missing branch name"
    assert_match(/branch/i, @client.stderr, "Should mention missing branch")
  end

  def test_should_reject_invocation_when_commit_is_not_found_in_repo
    @client.trigger(commit_hash: "deadbeef000000", branch: "main",
                    commit_validator: ->(_hash) { false })
    refute_equal 0, @client.exit_code, "Should reject unknown commit"
    assert_match(/not found/i, @client.stderr, "Should mention commit not found")
  end

  def test_should_return_exit_code_zero_when_fast_suite_passes
    @client.trigger(commit_hash: "abc1234", branch: "main")
    assert_equal 0, @client.exit_code, "Should return 0 when fast suite passes"
  end

  def test_should_return_nonzero_exit_code_when_fast_suite_fails
    trigger_with_failing_fast_suite
    refute_equal 0, @client.exit_code, "Should return non-zero when fast suite fails"
  end

  def test_should_display_test_runner_output_when_fast_suite_fails
    trigger_with_failing_fast_suite
    assert_match(/test_foo FAILED/, @client.stdout, "Should show test runner output")
    assert_match(/Fast suite failed/i, @client.stdout, "Should mention fast suite failure")
  end

  private

  def trigger_with_failing_fast_suite
    @client.close
    @client = TriggerCliClient.open(command_runner: FAST_SUITE_FAILS)
    @client.trigger(commit_hash: "abc1234", branch: "main")
  end
end
