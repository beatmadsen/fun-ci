# frozen_string_literal: true

module FunCi
  module Console
    # What a key means for the runs BoardData loads: moving the cursor,
    # quitting, and cancelling the run under the cursor (a running one after
    # the user confirms with `y`).
    class KeyHandler
      CONFIRMATION_ANSWERS = ["y", "n", :escape].freeze

      attr_reader :cursor_index

      def initialize(board_data:)
        @board_data = board_data
        @confirm_cancel = nil
      end

      # :quit when the key ends the session.
      def handle_key(key)
        return confirm(key) if @confirm_cancel
        return :quit if key == "q"

        act(key)
      end

      def confirming?
        !@confirm_cancel.nil?
      end

      def confirmation_run
        @confirm_cancel
      end

      private

      def act(key)
        case key
        when "j", :down then move_cursor_down
        when "k", :up then move_cursor_up
        when "c" then initiate_cancel
        end
      end

      # Onto the last run loaded, which loads the next page.
      def move_cursor_down
        last = @board_data.runs.length - 1
        return if last.negative?
        return @cursor_index = 0 if @cursor_index.nil?
        return unless @cursor_index < last

        @cursor_index += 1
        @board_data.load_more if @cursor_index == last
      end

      def move_cursor_up
        @cursor_index -= 1 if @cursor_index&.positive?
      end

      def initiate_cancel
        run = @cursor_index && @board_data.runs[@cursor_index]
        return unless run

        @board_data.cancel_run(run[:id]) if run[:status] == "scheduled"
        @confirm_cancel = run if run[:status] == "running"
      end

      def confirm(key)
        @board_data.cancel_run(@confirm_cancel[:id]) if key == "y"
        @confirm_cancel = nil if CONFIRMATION_ANSWERS.include?(key)
      end
    end
  end
end
