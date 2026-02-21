# frozen_string_literal: true

require_relative "trigger_cli_shared"

# Acceptance tests for trigger progress feedback.
#
# Verifies that the trigger CLI produces visible progress output
# suitable for git hook users, showing stage results as they complete.

class TestTriggerCliProgressFeedback < Minitest::Test
  def setup
    @client = TriggerCliClient.new(command_runner: INSTANT_SUCCESS_RUNNER)
  end

  def teardown
    @client.close
  end

  def test_should_show_phase_one_summary_when_all_stages_pass
    # Given a project where lint and build pass
    # When the trigger CLI is invoked
    @client.trigger(commit_hash: "abc1234", branch: "main")
    # Then stdout should show phase 1 passed
    assert_match(/lint ok/, @client.stdout, "Should show lint ok")
    assert_match(/build ok/, @client.stdout, "Should show build ok")
    assert_match(/phase 1 passed/i, @client.stdout, "Should summarize phase 1 passed")
  end

  def test_should_show_fast_ok_when_fast_suite_passes
    # Given a project where all stages pass
    # When the trigger CLI is invoked
    @client.trigger(commit_hash: "abc1234", branch: "main")
    # Then stdout should show fast ok
    assert_match(/fast ok/, @client.stdout, "Should show fast ok")
  end

  def test_should_show_slow_running_in_background
    # Given a project where all stages pass
    # When the trigger CLI is invoked
    @client.trigger(commit_hash: "abc1234", branch: "main")
    # Then stdout should indicate slow suite is running in background
    assert_match(/slow.*background/i, @client.stdout,
      "Should indicate slow suite running in background")
  end

  def test_should_show_phase_one_failed_when_lint_fails
    runner = ->(cmd) {
      cmd.include?("lint.sh") ? ["", FakeStatus.new(false, 1)] : ["", FakeStatus.new(true, 0)]
    }
    client = TriggerCliClient.new(command_runner: runner)
    client.trigger(commit_hash: "abc1234", branch: "main")
    assert_match(/lint FAIL/, client.stdout, "Should show lint FAIL")
    assert_match(/phase 1 failed/i, client.stdout, "Should summarize phase 1 failed")
  ensure
    client&.close
  end

  def test_should_show_phase_one_failed_when_build_fails
    runner = ->(cmd) {
      cmd.include?("build.sh") ? ["", FakeStatus.new(false, 1)] : ["", FakeStatus.new(true, 0)]
    }
    client = TriggerCliClient.new(command_runner: runner)
    client.trigger(commit_hash: "abc1234", branch: "main")
    assert_match(/build FAIL/, client.stdout, "Should show build FAIL")
    assert_match(/phase 1 failed/i, client.stdout, "Should summarize phase 1 failed")
  ensure
    client&.close
  end

  def test_should_show_fast_fail_when_fast_suite_fails
    runner = ->(cmd) {
      cmd.include?("fast.sh") ? ["", FakeStatus.new(false, 1)] : ["", FakeStatus.new(true, 0)]
    }
    client = TriggerCliClient.new(command_runner: runner)
    client.trigger(commit_hash: "abc1234", branch: "main")
    assert_match(/fast FAIL/, client.stdout, "Should show fast FAIL")
  ensure
    client&.close
  end

  def test_should_not_show_fast_result_when_phase_one_fails
    runner = ->(cmd) {
      cmd.include?("lint.sh") ? ["", FakeStatus.new(false, 1)] : ["", FakeStatus.new(true, 0)]
    }
    client = TriggerCliClient.new(command_runner: runner)
    client.trigger(commit_hash: "abc1234", branch: "main")
    refute_match(/fast ok/i, client.stdout, "Should not show fast ok when phase 1 failed")
    refute_match(/fast FAIL/i, client.stdout, "Should not show fast FAIL when phase 1 failed")
  ensure
    client&.close
  end
end
