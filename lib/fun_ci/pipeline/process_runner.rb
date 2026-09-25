# frozen_string_literal: true

module FunCi
  module Pipeline
    module ProcessRunner
      # Yields the pid of the process it starts, which leads a process group
      # of its own, so the caller can stop the command and all it spawned.
      def run_process_with_timeout(cmd, budget, chdir: Dir.pwd, &)
        reader, writer = IO.pipe
        pid = start(cmd, writer, chdir, &)
        output = Thread.new { read_until_closed(reader) }
        output.join(budget) ? process_finished(pid, output.value) : kill_process_group(pid)
      ensure
        ignoring_errors { reader&.close }
      end

      private

      def start(cmd, writer, chdir)
        pid = Process.spawn(cmd, out: writer, err: writer, pgroup: true, chdir: chdir)
        writer.close
        yield pid if block_given?
        pid
      end

      # On a timeout the reader is closed while this thread may still be
      # reading; whatever the killed command wrote no longer matters.
      def read_until_closed(reader)
        reader.read
      rescue IOError
        ""
      end

      def process_finished(pid, output)
        _, status = Process.waitpid2(pid)
        [output, status, false]
      end

      def kill_process_group(pid)
        %w[TERM KILL].each { |signal| ignoring_errors { Process.kill(signal, -pid) } }
        ignoring_errors { Process.waitpid(pid) }
        ["", nil, true]
      end

      def ignoring_errors
        yield
      rescue StandardError
        # A process that already exited or was already reaped needs nothing.
      end
    end
  end
end
