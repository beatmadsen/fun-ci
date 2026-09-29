# frozen_string_literal: true

# A FIFO that processes hold open for writing while they live, so a test
# waits for them to end as an event instead of looking at them at one
# instant: reading it reaches its end once the last holder is gone. A killed
# process can still show as running for a moment after its parent has been
# reaped, since a signal takes effect when the process next runs; and one
# whose own parent is gone can't be waited on. A shell takes hold with
# `hold`, and every process it starts after that holds on too. The reader
# opens first, without blocking, so no writer waits for it. Closing kills
# the holders' process group while any still hold on, since a holder the
# code under test failed to stop may be no child of the test's, out of
# reach of ProcessDeadline; once none do, the group may be gone and its id
# another's. A holder already killed may still hold on while it exits, and
# macOS then refuses the group's kill with EPERM, or finds it gone: either
# way nothing is left to stop.
class Lifeline
  # Yields a lifeline in `dir`, and closes it however the block ends.
  def self.open(dir)
    lifeline = new(dir)
    yield lifeline
  ensure
    lifeline&.close
  end

  def initialize(dir, kill: Process.method(:kill))
    @path = File.join(dir, "lifeline").tap { |fifo| File.mkfifo(fifo) }
    @group = File.join(dir, "lifeline.group")
    @reader = File.open(@path, File::RDONLY | File::NONBLOCK)
    @kill = kill
  end

  # The shell commands that take hold, and say so. The shell must lead a
  # process group of its own.
  def hold = "echo $$ > #{@group}; exec 3> #{@path}; echo held >&3"

  # Blocks until every holder has ended; wrap it in a deadline. False if
  # nothing ever took hold, which would otherwise look the same.
  def all_ended? = @reader.read == "held\n"

  def close
    @kill.call("KILL", -Integer(File.read(@group))) if held?
  rescue Errno::ESRCH, Errno::EPERM
    nil
  ensure
    @reader.close
  end

  private

  # Whether any holder still holds on; a holder records its group first.
  def held?
    loop { @reader.read_nonblock(4096) }
  rescue EOFError
    false
  rescue IO::WaitReadable
    true
  end
end
