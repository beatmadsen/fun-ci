# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/pipeline/process_runner"
require_relative "../../support/process_deadline"
require_relative "../../support/fifo"

# Before a command over budget is killed, what looks at it gets its pid
# (acceptance-tests.md, AT-10.17).
class TestProcessRunnerBeforeKill < Minitest::Test
  include ProcessDeadline

  class Host
    include FunCi::Pipeline::ProcessRunner
  end

  # The stage's group is still alive for what looks at it, and what that
  # makes the stage print is kept, as a JVM's thread dump after SIGQUIT would be.
  def setup = @dir = Dir.mktmpdir
  def teardown = FileUtils.remove_entry(@dir)

  def test_a_command_over_budget_is_still_running_when_the_hook_before_the_kill_runs
    stuck = fifo("stuck")
    dumped = fifo("dumped")
    command = "sh -c 'trap \"echo dumped; echo > #{dumped}\" USR1; echo > #{stuck}; while :; do sleep 0.05; done'"
    hook = ->(pid) { Process.kill("USR1", -pid) && Fifo.read(dumped) }
    output, = within_deadline { over_budget_with_hook(command, stuck, hook) }

    assert_includes output, "dumped\n"
  end

  private

  def fifo(name) = File.join(@dir, name).tap { |path| File.mkfifo(path) }

  def over_budget_with_hook(command, stuck, hook)
    launch = FunCi::Pipeline::ProcessRunner::Launch.new(before_kill: hook)
    Host.new.run_process_with_timeout(command, 30, launch: launch, timer: lambda { |_reading, _budget|
      Fifo.read(stuck) && nil
    })
  end
end
