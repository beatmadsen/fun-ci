# frozen_string_literal: true

# Makes a test's wait on real processes end, and leaves nothing running when
# it fails. If the block raises, or has not returned within SECONDS, every
# child of the test process is killed with its process group before the
# test fails. Without this, a mutant that loses a kill, a gate or a pipe
# close, or breaks the code after the stage has started, leaves the stage
# running in a process group of its own; a hang also runs on until the
# mutation lane's cap kills the test process. The children are found by
# asking ps, not the code under test, which a mutant may have stopped from
# reporting them.
#
# Once a wait has hung, the code under test is broken, and every later wait
# in the same process fails at once without starting anything: otherwise
# each test would hang in turn until the mutation lane's cap, which covers
# all of a mutant's tests together, cut one off mid-wait.
module ProcessDeadline
  SECONDS = 5

  class << self
    attr_accessor :hung
  end

  def within_deadline(&)
    flunk "an earlier wait on a process hung, so none is started" if ProcessDeadline.hung
    worker = Thread.new(&).tap { |thread| thread.report_on_exception = false }
    return worker.value if worker.join(SECONDS)

    give_up
  rescue StandardError
    stop_children
    raise
  end

  private

  def give_up
    ProcessDeadline.hung = true
    stop_children
    flunk "still waiting on a process after #{SECONDS} s"
  end

  def stop_children = children.each { |pid| kill_group(pid) }

  def children
    `ps -A -o pid= -o ppid=`.lines.map { |line| line.split.map(&:to_i) }
                            .select { |_, parent| parent == Process.pid }.map(&:first)
  end

  def kill_group(pid)
    Process.kill("KILL", -pid)
  rescue Errno::ESRCH, Errno::EPERM
    Process.kill("KILL", pid)
  end
end
