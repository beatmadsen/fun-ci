# frozen_string_literal: true

require_relative "trigger_cli_shared"

# Acceptance tests for trigger progress feedback.
#
# Verifies that the trigger CLI produces visible progress output
# suitable for git hook users, showing stage results as they complete.

class TestTriggerCliProgressFeedback < Minitest::Test
  def teardown
    @client&.close
  end

  def test_should_show_phase_one_summary_when_all_stages_pass
    trigger_with(INSTANT_SUCCESS_RUNNER)
    assert_match(/lint ok/, @client.stdout, "Should show lint ok")
    assert_match(/build ok/, @client.stdout, "Should show build ok")
    assert_match(/phase 1 passed/i, @client.stdout, "Should summarize phase 1 passed")
  end

  def test_should_show_fast_ok_when_fast_suite_passes
    trigger_with(INSTANT_SUCCESS_RUNNER)
    assert_match(/fast ok/, @client.stdout, "Should show fast ok")
  end

  def test_should_show_slow_running_in_background
    trigger_with(INSTANT_SUCCESS_RUNNER)
    assert_match(/slow.*background/i, @client.stdout,
                 "Should indicate slow suite running in background")
  end

  def test_should_show_phase_one_failed_when_lint_fails
    trigger_with(failing_script_runner("lint.sh"))
    assert_match(/lint FAIL/, @client.stdout, "Should show lint FAIL")
    assert_match(/phase 1 failed/i, @client.stdout, "Should summarize phase 1 failed")
  end

  def test_should_show_phase_one_failed_when_build_fails
    trigger_with(failing_script_runner("build.sh"))
    assert_match(/build FAIL/, @client.stdout, "Should show build FAIL")
    assert_match(/phase 1 failed/i, @client.stdout, "Should summarize phase 1 failed")
  end

  def test_should_show_fast_fail_when_fast_suite_fails
    trigger_with(failing_script_runner("fast.sh"))
    assert_match(/fast FAIL/, @client.stdout, "Should show fast FAIL")
  end

  def test_should_not_show_fast_result_when_phase_one_fails
    trigger_with(failing_script_runner("lint.sh"))
    refute_match(/fast ok/i, @client.stdout, "Should not show fast ok when phase 1 failed")
    refute_match(/fast FAIL/i, @client.stdout, "Should not show fast FAIL when phase 1 failed")
  end

  private

  def trigger_with(command_runner)
    @client = TriggerCliClient.open(command_runner: command_runner)
    @client.trigger(commit_hash: "abc1234", branch: "main")
  end
end
