# frozen_string_literal: true

require_relative "../pipeline/git_environment"
require_relative "command_reading"

module FunCi
  module Evidence
    # Runs a project's extractor command as stage scripts are run: in the
    # worktree, with the clean git environment, in a process group of its
    # own, killed with everything it started when `seconds` run out or when it
    # prints more than `limit` bytes. Its stdin is a file in `scratch`, and
    # its stderr another. A process that leaves the group (setsid) can't be
    # killed with it, so reading stops once the time and the drain are over.
    class CommandRunner
      Ran = Data.define(:stdout, :stderr, :exit_status, :killed)
      # bytes: the most of stdout kept; drain: seconds to read on after the command ends.
      Limits = Data.define(:bytes, :drain)
      LIMITS = Limits.new(bytes: 262_144, drain: 1)

      def initialize(dir:, env:, scratch:, limits: LIMITS)
        @launch = { chdir: dir, env: env }
        @scratch = scratch
        @limit = limits.bytes
        @drain = limits.drain
      end

      # env: added to the command's environment for this run.
      def call(command, stdin:, seconds:, env: {})
        File.write(path("context.json"), stdin)
        reader, writer = IO.pipe
        pid = spawn(command, writer, env)
        writer.close
        finish(pid, CommandReading.start(reader, @limit, -> { kill(pid) }), seconds)
      end

      private

      def path(name) = File.join(@scratch, name)

      def spawn(command, writer, env)
        Process.spawn(Pipeline::GitEnvironment::CLEAN.merge(@launch[:env], env), command,
                      in: path("context.json"), out: writer, err: path("stderr"), pgroup: true, chdir: @launch[:chdir])
      end

      def finish(pid, reading, seconds)
        waiter = Process.detach(pid)
        out_of_time = waiter.join(seconds).nil?
        kill(pid) if out_of_time
        status = waiter.value
        stdout = reading.finish(@drain)
        Ran.new(stdout: text(stdout.byteslice(0, @limit)), stderr: text(File.binread(path("stderr"))),
                exit_status: status.exitstatus, killed: killed(out_of_time, stdout))
      end

      def killed(out_of_time, stdout)
        return :budget if out_of_time

        stdout.bytesize > @limit ? :overflow : nil
      end

      # Kills the command and all it started in its group.
      def kill(pid)
        %w[TERM KILL].each { |signal| ignoring_gone { Process.kill(signal, -pid) } }
      end

      def ignoring_gone
        yield
      rescue Errno::ESRCH, Errno::EPERM
        # The group has gone, or what is left of it is no longer ours.
      end

      def text(bytes) = bytes.force_encoding(Encoding::UTF_8).scrub("?")
    end
  end
end
