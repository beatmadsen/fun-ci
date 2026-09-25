# frozen_string_literal: true

require "tempfile"

# A green run writes nothing to stderr. Anything that lands there (a dying
# thread, an exception in a forked child) is an error no test asserted on,
# so the run fails. fd 2 is redirected when the run starts, before the
# parallel workers fork, so they and their children write to the same file;
# a test file that fails to load still reports to the terminal.
module StrayStderrGuard
  module RedirectOnRun
    def run(...)
      StrayStderrGuard.redirect
      super
    end
  end

  def self.install
    Minitest.singleton_class.prepend(RedirectOnRun)
  end

  def self.redirect
    log = Tempfile.new("fun-ci-stderr")
    terminal = $stderr.dup
    $stderr.reopen(log)
    main_pid = Process.pid
    Minitest.after_run { report(log, terminal) if Process.pid == main_pid }
  end

  def self.report(log, terminal)
    $stderr.reopen(terminal)
    written = File.read(log.path)
    return if written.empty?

    warn "Stray output on stderr fails the run:\n#{written}"
    exit 1
  end
end
