# frozen_string_literal: true

# A FIFO that processes hold open for writing while they live, so a test
# waits for them to end as an event instead of looking at them at one
# instant: reading it reaches its end once the last holder is gone. A killed
# process can still show as running for a moment after its parent has been
# reaped, since a signal takes effect when the process next runs; and one
# whose own parent is gone can't be waited on. A shell takes hold with
# `hold`, and every process it starts after that holds on too. The reader
# opens first, without blocking, so no writer waits for it. Closing kills
# the holders' process group, since a holder the code under test failed to
# stop may be no child of the test's, out of reach of ProcessDeadline.
class Lifeline
  def initialize(dir)
    @path = File.join(dir, "lifeline").tap { |fifo| File.mkfifo(fifo) }
    @group = File.join(dir, "lifeline.group")
    @reader = File.open(@path, File::RDONLY | File::NONBLOCK)
  end

  # The shell commands that take hold, and say so. The shell must lead a
  # process group of its own.
  def hold = "echo $$ > #{@group}; exec 3> #{@path}; echo held >&3"

  # Blocks until every holder has ended; wrap it in a deadline. False if
  # nothing ever took hold, which would otherwise look the same.
  def all_ended? = @reader.read == "held\n"

  def close
    Process.kill("KILL", -Integer(File.read(@group))) if File.exist?(@group)
  rescue Errno::ESRCH
    nil
  ensure
    @reader.close
  end
end
