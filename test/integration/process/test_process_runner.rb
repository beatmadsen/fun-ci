# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/pipeline/process_runner"
require "fun_ci/pipeline/trigger_params"

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

  def test_a_command_killed_over_budget_leaves_no_child_unreaped
    assert_equal("none", in_fresh_process { run_command("exec tail -f /dev/null", 0) })
  end

  def test_reports_the_process_it_started
    started = []
    _, status, = Host.new.run_process_with_timeout("true", 30) { |pid| started << pid }

    assert_equal [status.pid], started
  end

  # So a cancel never misses a stage that has started: whoever is told the
  # pid has recorded it before the stage's script runs.
  def test_the_command_starts_only_after_the_caller_has_its_pid
    Dir.mktmpdir do |dir|
      marker = File.join(dir, "ran")
      seen = []
      Host.new.run_process_with_timeout("touch #{marker}", 30) { seen << File.exist?(marker) }

      assert_equal [false], seen
    end
  end

  def test_seams_without_a_runner_run_the_command_for_real
    _, status, = FunCi::Pipeline::Seams.new.executor(Dir.tmpdir).call("sh -c 'exit 4'", 30)

    assert_equal 4, status.exitstatus
  end

  private

  # Runs the block in a child of its own, so the only children left to reap
  # afterwards are the block's, and answers whether any was left unreaped.
  def in_fresh_process(&)
    reader, writer = IO.pipe
    pid = fork { report_unreaped(writer, &) }
    writer.close
    Process.wait(pid)
    reader.read
  end

  def report_unreaped(writer)
    yield
    writer.write(Process.wait(-1, Process::WNOHANG) ? "a zombie" : "a child still running")
  rescue Errno::ECHILD
    writer.write("none")
  ensure
    exit!(0)
  end

  def run_command(script, budget)
    Host.new.run_process_with_timeout("sh -c '#{script}'", budget)
  end
end
