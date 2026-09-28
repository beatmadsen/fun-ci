# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/pipeline/process_runner"
require_relative "../../support/process_deadline"
require_relative "../../support/fifo"

# A command over budget, stuck once it has printed: the budget runs out when
# it writes to a FIFO, so no outcome depends on timing. What it printed is
# the only clue to what it was stuck on (AT-9.5), and what looks at it before
# the kill gets its pid (acceptance-tests.md, AT-10.17).
class TestProcessRunnerOverBudget < Minitest::Test
  include ProcessDeadline

  class Host
    include FunCi::Pipeline::ProcessRunner
  end

  # Leaves the process group, waits to be let go through the FIFO it is
  # given, then prints `late`.
  ESCAPEE = "ruby -rtimeout -e 'Process.setsid; Timeout.timeout(5) { File.read(ARGV[0]) }; sleep 0.2; puts :late'"

  def setup = @dir = Dir.mktmpdir
  def teardown = FileUtils.remove_entry(@dir)

  def test_a_command_over_budget_keeps_what_it_printed_before_the_kill
    stuck = fifo("stuck")

    assert_equal "partial\n", over_budget("sh -c 'echo partial; echo > #{stuck}; exec tail -f /dev/null'", stuck)
  end

  # The stage's group is still alive for what looks at it, and what that
  # makes the stage print is kept, as a JVM's thread dump after SIGQUIT would be.
  def test_a_command_over_budget_is_still_running_when_the_hook_before_the_kill_runs
    stuck = fifo("stuck")
    dumped = fifo("dumped")
    command = "sh -c 'trap \"echo dumped; echo > #{dumped}\" USR1; echo > #{stuck}; while :; do sleep 0.05; done'"
    hook = ->(pid) { Process.kill("USR1", -pid) && Fifo.read(dumped) }

    assert_includes over_budget(command, stuck, hook), "dumped\n"
  end

  # Output can still come after the kill, from whatever still holds the
  # stage's stdout: here a process that left the group, which prints a
  # fifth of a second after the hook before the kill lets it, well within
  # the drain, and ends. Reading only until the kill would miss it.
  def test_a_command_over_budget_keeps_what_is_printed_while_its_output_drains
    stuck = fifo("stuck")
    release = fifo("release")
    command = %(sh -c "#{ESCAPEE} #{release} & echo > #{stuck}; exec tail -f /dev/null")

    assert_equal "late\n", over_budget(command, stuck, ->(_pid) { File.write(release, "go") })
  end

  private

  def fifo(name) = File.join(@dir, name).tap { |path| File.mkfifo(path) }

  # What the command printed, once it wrote to `stuck` and `hook` ran before the kill.
  def over_budget(command, stuck, hook = nil)
    launch = FunCi::Pipeline::ProcessRunner::Launch.new(before_kill: hook)
    within_deadline do
      Host.new.run_process_with_timeout(command, 30, launch: launch, timer: ->(*) { Fifo.read(stuck) && nil }).first
    end
  end
end
