# frozen_string_literal: true

module FunCi
  module Tui
    class KeyHandler
      attr_reader :cursor_index

      def initialize(board_data:)
        @board_data = board_data
        @cursor_index = nil
        @confirm_cancel = nil
      end

      def handle_key(key)
        if @confirm_cancel
          handle_confirm_key(key)
          return
        end

        case key
        when "q"
          :quit
        when "j", :down
          move_cursor_down
        when "k", :up
          move_cursor_up
        when "c"
          initiate_cancel
        end
      end

      def confirming?
        !@confirm_cancel.nil?
      end

      def confirmation_run
        @confirm_cancel
      end

      private

      def move_cursor_down
        runs = @board_data.runs
        return if runs.empty?

        if @cursor_index.nil?
          @cursor_index = 0
        elsif @cursor_index < runs.length - 1
          @cursor_index += 1
          @board_data.load_more if @cursor_index == runs.length - 1
        end
      end

      def move_cursor_up
        return if @cursor_index.nil?

        @cursor_index -= 1 if @cursor_index > 0
      end

      def initiate_cancel
        return if @cursor_index.nil?

        runs = @board_data.runs
        return if @cursor_index >= runs.length

        run = runs[@cursor_index]
        case run[:status]
        when "scheduled"
          @board_data.cancel_run(run[:id])
        when "running"
          @confirm_cancel = run
        end
      end

      def handle_confirm_key(key)
        case key
        when "y"
          @board_data.cancel_run(@confirm_cancel[:id])
          @confirm_cancel = nil
        when "n", :escape
          @confirm_cancel = nil
        end
      end
    end
  end
end
