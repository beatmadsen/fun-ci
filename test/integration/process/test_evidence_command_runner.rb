# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/process_deadline"
require_relative "../../support/process_state"
require "tmpdir"
require "fun_ci/evidence/command_runner"

# A project's extractor command, run for real (architecture.md, "Evidence of a failed stage").
class TestEvidenceCommandRunner < Minitest::Test
  include ProcessDeadline

  def setup = @dir = Dir.mktmpdir
  def teardown = FileUtils.remove_entry(@dir)

  def test_should_give_the_command_its_stdin_and_keep_its_stdout
    assert_equal "context\n", ran("cat").stdout
  end

  def test_should_run_the_command_in_the_worktree
    assert_equal "#{File.realpath(@dir)}\n", ran("pwd -P").stdout
  end

  def test_should_keep_the_command_s_exit_status
    assert_equal 3, ran("exit 3").exit_status
  end

  def test_should_keep_what_the_command_printed_to_stderr
    assert_equal "oops\n", ran("echo oops >&2").stderr
  end

  def test_should_kill_a_command_the_budget_runs_out_on
    assert_equal :budget, ran("exec sleep 30", seconds: 0.2).killed
  end

  def test_should_kill_what_the_command_started
    ran("sleep 30 & echo $! > child.pid; wait", seconds: 0.2)

    refute ProcessState.running?(File.read(File.join(@dir, "child.pid")).to_i)
  end

  def test_should_kill_a_command_that_prints_more_than_its_limit
    assert_equal :overflow, ran("yes", limit: 1000).killed
  end

  def test_should_keep_stdout_up_to_its_limit
    assert_equal 1000, ran("yes", limit: 1000).stdout.bytesize
  end

  def test_should_not_kill_a_command_that_prints_exactly_its_limit
    assert_nil ran("printf %1000s x", limit: 1000).killed
  end

  # A child that leaves the process group keeps stdout open and can't be
  # killed with it; the runner stops reading once the budget and the drain
  # are over, so the child can't hold the evidence up.
  def test_should_not_wait_on_a_child_that_escaped_its_process_group
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    ran("ruby -e 'Process.setsid; File.write(\"escaped.pid\", Process.pid.to_s); sleep 30' & wait", seconds: 0.5)

    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 5
  ensure
    escaped = File.join(@dir, "escaped.pid")
    Process.kill("KILL", File.read(escaped).to_i) if File.exist?(escaped)
  end

  private

  def ran(command, seconds: 10, limit: 262_144)
    limits = FunCi::Evidence::CommandRunner::Limits.new(bytes: limit, drain: 0.2)
    runner = FunCi::Evidence::CommandRunner.new(dir: @dir, env: {}, scratch: @dir, limits: limits)
    within_deadline { runner.call(command, stdin: "context\n", seconds: seconds) }
  end
end
