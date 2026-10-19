# frozen_string_literal: true

require_relative "stray_processes"
require_relative "open_files"

# Nothing a test run starts outlives it. When the run ends, in the process
# that installed this (never a parallel worker, whose siblings may still be
# running), each live process whose command line names one of the run's temp
# roots, such as a stage or job script in a test's project, or that holds a
# file open in one, such as the output a test's shell inherited, is killed
# with its process group, named on stderr, and fails the run.
module ProcessLeakGuard
  def self.install(roots)
    owner = Process.pid
    Minitest.after_run { check(roots) if Process.pid == owner }
  end

  def self.check(roots)
    leaked = StrayProcesses.stop(roots, holders: OpenFiles.holders(roots))
    return if leaked.empty?

    warn("Processes outlived the test run, and were killed:", *leaked.map { |line| "  #{line}" })
    exit false
  end
end
