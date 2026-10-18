# frozen_string_literal: true

# What `nice -n N` gives a command this process starts: N above this
# process's own niceness, which a test run need not start at 0 (a background
# shell's, or fun-ci's slow suite at nice 10 off macOS), up to the 19 the
# system allows.
module Niceness
  def niced_by(increment) = [Process.getpriority(Process::PRIO_PROCESS, 0) + increment, 19].min.to_s
end
