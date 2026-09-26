# frozen_string_literal: true

require_relative "run_message"
require_relative "console_events"

module FunCi
  module Console
    # What the console shows: the page of runs BoardData reads that the View
    # puts on screen, and the clock's time, as a protocol `board` message,
    # after the `event`s for what changed since the last one.
    class ConsoleState
      KEYS = { "up" => :up, "down" => :down, "esc" => :escape, "ctrl_c" => "q", "enter" => :enter }.freeze

      def initialize(board_data:, view:, clock:)
        @board_data = board_data
        @view = view
        @clock = clock
        @events = ConsoleEvents.new
      end

      # :quit when the key ends the session.
      def press(key) = @view.press(KEYS.fetch(key, key))

      # Pages for a terminal of `rows`.
      def resize(rows) = @board_data.resize(@view.resize(rows))

      def updates
        @board_data.record_dead_slow_suites
        runs = @board_data.runs
        [*@events.since_last(runs), board(runs)]
      end

      private

      def board(runs)
        page = @view.page(runs, more: @board_data.more?)
        { t: "board", now: @clock.call.to_i, streak: @board_data.streak, **page,
          runs: page[:runs].map { |run| RunMessage.from(run) } }
      end
    end
  end
end
