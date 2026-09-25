# frozen_string_literal: true

require_relative "run_message"

module FunCi
  module Console
    # What the console shows: the runs BoardData reads, where KeyHandler's
    # cursor is, and the clock's time, as a protocol `board` message.
    class ConsoleState
      KEYS = { "up" => :up, "down" => :down, "esc" => :escape, "ctrl_c" => "q", "enter" => :enter }.freeze

      def initialize(board_data:, key_handler:, clock:)
        @board_data = board_data
        @key_handler = key_handler
        @clock = clock
      end

      # :quit when the key ends the session.
      def press(key) = @key_handler.handle_key(KEYS.fetch(key, key))

      def board
        { t: "board", now: @clock.call.to_i, streak: @board_data.streak, cursor: @key_handler.cursor_index,
          confirming: @key_handler.confirming?, has_more: false,
          runs: @board_data.runs.map { |run| RunMessage.from(run) } }
      end
    end
  end
end
