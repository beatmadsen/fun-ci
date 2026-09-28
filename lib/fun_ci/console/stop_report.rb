# frozen_string_literal: true

module FunCi
  module Console
    # Why the console stopped, in the console log and, unless the user quit
    # and the renderer exited cleanly, on stderr: the terminal is the
    # renderer's until it exits, so an error is only told once it has.
    class StopReport
      CAUSES = { quit: "the user quit", ended: "the renderer went away" }.freeze

      # `outcome`: :quit, :ended, or the error that stopped the console.
      def initialize(outcome, status)
        @outcome = outcome
        @status = status
      end

      # The exit status: 0 once the user has quit, 1 otherwise.
      def tell(log, stderr)
        log.write("console stopped: #{cause}; the renderer exited (#{@status})")
        return 0 if @outcome == :quit && @status.success?

        stderr.puts "#{failure}; see .fun-ci/console.log"
        1
      end

      private

      def failed? = @outcome.is_a?(Exception)

      def cause = failed? ? "it failed: #{error}\n#{trace}" : CAUSES.fetch(@outcome)

      def error = "#{@outcome.class}: #{@outcome.message}"

      def trace = @outcome.backtrace.map { |line| "  #{line}" }.join("\n")

      def failure = failed? ? "fun-ci console failed (#{error})" : "fun-ci console: the renderer stopped (#{@status})"
    end
  end
end
