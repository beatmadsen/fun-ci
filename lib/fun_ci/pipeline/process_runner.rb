# frozen_string_literal: true

require_relative "gate"
require_relative "git_environment"
require_relative "output_window"

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

      # Where the command runs, what it finds in its environment besides
      # fun-ci's own, the window what it prints is written to, what to do
      # with its pid when it runs over budget, before it is killed, the
      # open files it holds as long as it runs, such as a lock, and what it
      # is run under (a Priorities prefix, "" for fun-ci's own priority).
      Launch = Data.define(:chdir, :env, :output, :before_kill, :held, :priority)

      class Launch
        def initialize(**given)
          super(chdir: Dir.pwd, env: {}, output: OutputWindow.in_memory, before_kill: nil, held: [], priority: "",
                **given)
        end
      end

      # Where the first file a command holds is open in it: past the gate's 9.
      FIRST_HELD = 10

      # { descriptor in the command => file } for the files it holds. Not their
      # own descriptors, which in a process with few files open may be the gate's.
      def self.held_descriptors(files) = files.each_with_index.to_h { |file, index| [FIRST_HELD + index, file] }

      # A command started and let go, and the pipe that carries what it prints.
      Started = Data.define(:pid, :reader)

      def run_process_with_timeout(cmd, budget, launch: Launch.new, timer: BUDGET, &)
        await_process(start_process(cmd, launch, &), budget, launch: launch, timer: timer)
      end

      # Starts the command and yields its pid before letting it run.
      def start_process(cmd, launch = Launch.new, &)
        reader, writer = IO.pipe
        Started.new(pid: start(cmd, writer, launch, &), reader: reader)
      end

      # [what it printed, its status (nil when killed), whether it ran over budget].
      def await_process(started, budget, launch: Launch.new, timer: BUDGET)
        printed = launch.output
        reading = Thread.new { read_until_closed(started.reader, printed) }
        return process_finished(started.pid, text(reading.value)) if timer.call(reading, budget)

        over_budget(started.pid, reading, launch)
      ensure
        ignoring_errors { started.reader.close }
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
        Process.spawn(GitEnvironment::CLEAN.merge(launch.env), format(GATED, "#{launch.priority}#{cmd}"),
                      out: writer, err: writer, 9 => gate.child_end, pgroup: true, chdir: launch.chdir, **held(launch))
      end

      def held(launch) = ProcessRunner.held_descriptors(launch.held)

      # The reader may be closed while this thread still reads, once a killed
      # command's output has drained or stopped coming.
      def read_until_closed(reader, printed)
        loop { printed << reader.readpartial(65_536) }
      rescue IOError
        printed
      end

      # What looks at the stage before the kill does so while its output is still read.
      def over_budget(pid, reading, launch)
        launch.before_kill&.call(pid)
        kill_process_group(pid)
        [drained(reading, launch.output), nil, true]
      end

      def drained(reading, printed)
        reading.join(DRAIN_SECONDS)
        text(printed)
      end

      def text(window) = window.text.force_encoding(Encoding.default_external)

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
