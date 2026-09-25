# frozen_string_literal: true

require_relative "run_message"
require_relative "stage_events"

module FunCi
  module Console
    # What the console shows: the runs BoardData reads, where KeyHandler's
    # cursor is, and the clock's time, as a protocol `board` message, after
    # an `event` for each stage that changed since the last one.
    class ConsoleState
      KEYS = { "up" => :up, "down" => :down, "esc" => :escape, "ctrl_c" => "q", "enter" => :enter }.freeze

      def initialize(board_data:, key_handler:, clock:)
        @board_data = board_data
        @key_handler = key_handler
        @clock = clock
        @events = StageEvents.new
      end

      # :quit when the key ends the session.
      def press(key) = @key_handler.handle_key(KEYS.fetch(key, key))

      def updates
        runs = @board_data.runs
        [*@events.since_last(runs), board(runs)]
      end

      private

      def board(runs)
        { t: "board", now: @clock.call.to_i, streak: @board_data.streak, cursor: @key_handler.cursor_index,
          confirming: @key_handler.confirming?, has_more: false, runs: runs.map { |run| RunMessage.from(run) } }
      end
    end
  end
end
