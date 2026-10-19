# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/pipeline/process_runner"
require_relative "../../support/process_deadline"
require_relative "../../support/fifo"
require_relative "../../support/lifeline"

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
  # given, then for the stage, the pid it is given, to be killed and reaped,
  # and prints `late`. Its stderr stays out of the output asserted on.
  ESCAPEE = "ruby -rtimeout -e 'Process.setsid; Timeout.timeout(5) { File.read(ARGV[0]) }; " \
            "Timeout.timeout(5) { sleep 0.01 while (Process.kill(0, ARGV[1].to_i) rescue nil) }; puts :late'"

  # Leaves for a session of its own, then says so through the FIFO it is
  # given, and sleeps. Run from the test's directory, its command line names
  # it, so the stray-process guard stops it if the kill doesn't.
  DETACHED = "use POSIX; POSIX::setsid(); open(my $f, '>', $ARGV[0]); close $f; sleep 300;\n"

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
  # stage's stdout: here a process that left the group and, forked twice,
  # its parent's tree, so the kill can't reach it; let go by the hook before
  # the kill, it prints once the stage is gone, and ends. The drain is as
  # long as the test's deadline, so it ends as the output does, not on a
  # clock. Reading only until the kill would miss it.
  def test_a_command_over_budget_keeps_what_is_printed_while_its_output_drains
    stuck = fifo("stuck")
    release = fifo("release")
    command = %(sh -c "(#{ESCAPEE} #{release} $$ 2>/dev/null &); echo > #{stuck}; exec tail -f /dev/null")
    hook = ->(_pid) { File.write(release, "go") }

    assert_equal "late\n", over_budget(command, stuck, hook, drain: ProcessDeadline::SECONDS)
  end

  # As Playwright's web server, which Node starts in a session of its own.
  def test_a_command_over_budget_takes_what_it_started_in_a_session_of_its_own_with_it
    stuck = fifo("stuck")
    Lifeline.open(@dir) do |lifeline|
      escapee = File.join(@dir, "escapee.pl").tap { |path| File.write(path, DETACHED) }
      command = %(sh -c "#{lifeline.hold}; perl #{escapee} #{stuck} & wait")
      over_budget(command, stuck)

      assert(within_deadline { lifeline.all_ended? })
    end
  end

  private

  def fifo(name) = File.join(@dir, name).tap { |path| File.mkfifo(path) }

  # What the command printed, once it wrote to `stuck` and `hook` ran before the kill.
  def over_budget(command, stuck, hook = nil, drain: FunCi::Pipeline::ProcessRunner::DRAIN_SECONDS)
    launch = FunCi::Pipeline::ProcessRunner::Launch.new(before_kill: hook, drain: drain)
    within_deadline do
      Host.new.run_process_with_timeout(command, 30, launch: launch, timer: ->(*) { Fifo.read(stuck) && nil }).first
    end
  end
end
