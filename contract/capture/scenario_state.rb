# frozen_string_literal: true

require_relative "../../lib/fun_ci/tui/board"
require_relative "protocol_run"

module FunCi
  module Contract
    # Folds scenario messages into the terminal size, the clock and the board.
    class ScenarioState
      attr_reader :cols, :rows

      def initialize
        @cols = 80
        @rows = 24
        @board = { "runs" => [] }
        @now = Rational(0)
      end

      def apply(message)
        handler = { "resize" => :resize, "board" => :replace_board, "tick" => :tick }[message["t"]]
        send(handler, message) if handler
      end

      def board
        Tui::Board.new(runs: @board["runs"].map { |run| ProtocolRun.to_tui(run) },
                       streak: @board["streak"], cursor_index: @board["cursor"],
                       confirming: @board["confirming"], now: Time.at(@now))
      end

      private

      def resize(message)
        @cols = message["cols"]
        @rows = message["rows"]
      end

      def replace_board(message)
        @board = message
        @now = Rational(message["now"])
      end

      def tick(message)
        @now += Rational(message["ms"], 1000)
      end
    end
  end
end
