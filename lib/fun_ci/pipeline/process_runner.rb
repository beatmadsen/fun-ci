# frozen_string_literal: true

require_relative "gate"
require_relative "git_environment"

module FunCi
  module Pipeline
    module ProcessRunner
      # The command waits on fd 9 until the caller has been told its pid, so a
      # cancel that reads the recorded pid can never miss a stage that has
      # started; exec keeps the pid and the process group. If the caller dies
      # first, the pipe closes and the command never runs.
      GATED = "read _ <&9 || exit 125; exec 9<&-; exec %s"

      # Yields the pid of the process it starts, which leads a process group
      # of its own, so the caller can stop the command and all it spawned.
      # A command over budget answers what it printed before the kill, which
      # is the only clue to what it was stuck on (acceptance-tests.md, AT-9.5).
      # `timer` answers whether the reading finished within the budget.
      BUDGET = ->(reading, budget) { reading.join(budget) }
      # How long a killed command's last output may take to drain.
      DRAIN_SECONDS = 1

      # Where the command runs, and what it finds in its environment besides fun-ci's own.
      Launch = Data.define(:chdir, :env) do
        def initialize(chdir: Dir.pwd, env: {}) = super
      end

      def run_process_with_timeout(cmd, budget, launch: Launch.new, timer: BUDGET, &)
        reader, writer = IO.pipe
        pid = start(cmd, writer, launch, &)
        printed = String.new
        reading = Thread.new { read_until_closed(reader, printed) }
        timer.call(reading, budget) ? process_finished(pid, text(reading.value)) : over_budget(pid, reading, printed)
      ensure
        ignoring_errors { reader&.close }
      end

      private

      def start(cmd, writer, launch)
        gate = Gate.create
        pid = spawn_gated(cmd, writer, gate, launch)
        [writer, gate.child_end].each(&:close)
        yield pid if block_given?
        gate.open
        pid
      end

      def spawn_gated(cmd, writer, gate, launch)
        Process.spawn(GitEnvironment::CLEAN.merge(launch.env), format(GATED, cmd),
                      out: writer, err: writer, 9 => gate.child_end, pgroup: true, chdir: launch.chdir)
      end

      # The reader may be closed while this thread still reads, once a killed
      # command's output has drained or stopped coming.
      def read_until_closed(reader, printed)
        loop { printed << reader.readpartial(65_536) }
      rescue IOError
        printed
      end

      def over_budget(pid, reading, printed)
        kill_process_group(pid)
        [drained(reading, printed), nil, true]
      end

      def drained(reading, printed)
        reading.join(DRAIN_SECONDS)
        text(printed)
      end

      def text(bytes) = bytes.dup.force_encoding(Encoding.default_external)

      def process_finished(pid, output)
        _, status = Process.waitpid2(pid)
        [output, status, false]
      end

      def kill_process_group(pid)
        %w[TERM KILL].each { |signal| ignoring_errors { Process.kill(signal, -pid) } }
        ignoring_errors { Process.waitpid(pid) }
      end

      def ignoring_errors
        yield
      rescue StandardError
        # A process that already exited or was already reaped needs nothing.
      end
    end
  end
end
