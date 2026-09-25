# frozen_string_literal: true

require "json"

module FunCi
  module Console
    # The renderer as a child process (renderer-protocol.md): messages go to
    # its stdin as JSON lines and its lines come from its stdout. No wait on
    # it is endless, and one that will not exit is stopped.
    class RendererProcess
      class Silent < StandardError; end

      # `err` takes the renderer's stderr, which is for diagnostics only.
      def self.start(command, err: File::NULL)
        input, to_renderer = IO.pipe
        from_renderer, output = IO.pipe
        pid = Process.spawn(*command, in: input, out: output, err: err)
        [input, output].each(&:close)
        new(waiter: Process.detach(pid), input: to_renderer, output: from_renderer)
      end

      def initialize(waiter:, input:, output:)
        @waiter = waiter
        @input = input
        @output = output
      end

      def write(message) = @input.puts(JSON.generate(message))

      # The renderer's next line, or nil once it has closed its output.
      # Raises Silent when nothing comes within `patience` seconds.
      def next_line(patience:)
        raise Silent, "no word from the renderer in #{patience} s" unless @output.wait_readable(patience)

        @output.gets&.chomp
      end

      # Closes the renderer's input, which it takes as `quit`, and answers how
      # it exited; one still running after `patience` seconds is stopped.
      def finish(patience:)
        @input.close unless @input.closed?
        stop(patience) unless @waiter.join(patience)
        @output.close
        @waiter.value
      end

      private

      # SIGTERM first, on which the renderer restores the terminal.
      def stop(patience)
        Process.kill("TERM", @waiter.pid)
        Process.kill("KILL", @waiter.pid) unless @waiter.join(patience)
      rescue Errno::ESRCH
        nil
      end
    end
  end
end
