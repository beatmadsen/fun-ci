# frozen_string_literal: true

require_relative "../test_helper"
require_relative "trigger_cli_client"

# Acceptance tests for CLI invocation and argument handling.
#
# Covers: valid/invalid arguments, commit validation,
# and basic fast suite pass/fail exit codes.

class TestTriggerCliHappyPath < Minitest::Test
  def setup
    @client = TriggerCliClient.new
  end

  def teardown
    @client.close
  end

  # --- Invocation and argument handling ---

  def test_should_accept_commit_hash_and_branch_name
    # Given a valid commit hash and branch name
    # When the trigger CLI is invoked with those arguments
    @client.trigger(commit_hash: "abc1234", branch: "main")
    # Then it should execute without an argument error
    assert_equal 0, @client.exit_code, "Should accept valid commit and branch"
  end

  def test_should_reject_invocation_when_commit_hash_is_missing
    # Given no commit hash is provided
    # When the trigger CLI is invoked with only a branch name
    @client.trigger_raw(args: ["main"])
    # Then exit code should be non-zero
    refute_equal 0, @client.exit_code, "Should reject missing commit hash"
    # And stderr should mention the missing commit
    assert_match(/commit/i, @client.stderr, "Should mention missing commit")
  end

  def test_should_reject_invocation_when_branch_name_is_missing
    # Given no branch name is provided
    # When the trigger CLI is invoked with only a commit hash
    @client.trigger_raw(args: ["abc1234"])
    # Then exit code should be non-zero
    refute_equal 0, @client.exit_code, "Should reject missing branch name"
    # And stderr should mention the missing branch name
    assert_match(/branch/i, @client.stderr, "Should mention missing branch")
  end

  def test_should_reject_invocation_when_commit_is_not_found_in_repo
    # Given a commit hash that does not exist in the repository
    # When the trigger CLI is invoked with a validator that rejects the commit
    @client.trigger(commit_hash: "deadbeef000000", branch: "main",
      commit_validator: ->(_hash) { false })
    # Then exit code should be non-zero
    refute_equal 0, @client.exit_code, "Should reject unknown commit"
    # And stderr should say the commit was not found
    assert_match(/not found/i, @client.stderr, "Should mention commit not found")
  end

  # --- Foreground behavior: fast suite result ---

  def test_should_return_exit_code_zero_when_fast_suite_passes
    # Given a project with a fast suite that passes
    # When the trigger CLI is invoked
    @client.trigger(commit_hash: "abc1234", branch: "main")
    # Then exit code should be 0
    assert_equal 0, @client.exit_code, "Should return 0 when fast suite passes"
  end

  def test_should_return_nonzero_exit_code_when_fast_suite_fails
    # Given a project with a fast suite that has failing tests
    # When the trigger CLI is invoked
    @client.trigger(commit_hash: "abc1234", branch: "main",
      scripts: { "fast.sh" => "echo 'test_foo FAILED'; exit 1" })
    # Then exit code should be non-zero
    refute_equal 0, @client.exit_code, "Should return non-zero when fast suite fails"
  end

  def test_should_display_test_runner_output_when_fast_suite_fails
    # Given a project with a fast suite that has failing tests
    # When the trigger CLI is invoked
    @client.trigger(commit_hash: "abc1234", branch: "main",
      scripts: { "fast.sh" => "echo 'test_foo FAILED'; exit 1" })
    # Then stdout should contain the test runner output
    assert_match(/test_foo FAILED/, @client.stdout, "Should show test runner output")
    # And stdout should contain "Fast suite failed"
    assert_match(/Fast suite failed/i, @client.stdout, "Should mention fast suite failure")
  end
end
