# frozen_string_literal: true

module FunCi
  module Console
    # The port to the renderer, noting in the console log every EVERY seconds
    # how many boards went out and the newest run on the last, so a console
    # that stops showing new runs leaves a record of what Ruby was sending.
    class BoardHeartbeat
      EVERY = 600

      # `clock` answers seconds; only differences between its answers count.
      def initialize(port, log:, clock:)
        @port = port
        @log = log
        @clock = clock
        @beat = { since: clock.call, boards: 0 }
      end

      def write(message)
        @port.write(message)
        note(message) if message[:t] == "board"
      end

      private

      def note(board)
        now = @clock.call
        @beat = { since: @beat[:since], boards: @beat[:boards] + 1 }
        tell(now, board) if now - @beat[:since] >= EVERY
      end

      def tell(now, board)
        @log.write("#{@beat[:boards]} boards in the last #{(now - @beat[:since]).round} s; #{newest(board[:runs])}")
        @beat = { since: now, boards: 0 }
      end

      def newest(runs) = runs.empty? ? "the last showed no runs" : "the newest run on the last: #{runs.first[:id]}"
    end
  end
end
