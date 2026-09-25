# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/process_runner"

# Real processes: this is the code every stage script runs through.
class TestProcessRunner < Minitest::Test
  class Host
    include FunCi::Pipeline::ProcessRunner
  end

  def test_a_finished_command_returns_its_stdout_and_stderr_together
    output, = run_command("echo out; echo err >&2", 30)

    assert_equal "out\nerr\n", output
  end

  def test_a_finished_command_reports_it_did_not_time_out
    _, status, timed_out = run_command("true", 30)

    assert_equal [true, false], [status.success?, timed_out]
  end

  def test_a_failing_command_returns_its_failed_status
    _, status, = run_command("exit 3", 30)

    assert_equal 3, status.exitstatus
  end

  # With a budget of zero a command that never ends can't finish first, so the
  # outcome doesn't depend on timing. If the kill were lost, this would hang.
  def test_a_command_over_budget_is_killed_and_reported_as_timed_out
    assert_equal ["", nil, true], run_command("exec tail -f /dev/null", 0)
  end

  private

  def run_command(script, budget)
    Host.new.run_process_with_timeout("sh -c '#{script}'", budget)
  end
end
