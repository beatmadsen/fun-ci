# frozen_string_literal: true

module FunCi
  module Console
    # What a key means for the runs BoardData loads, and the daily and weekly
    # jobs after them: moving the cursor through both, quitting, and
    # cancelling the run or job under the cursor (a running one after the
    # user confirms with `y`).
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

      private

      def act(key)
        case key
        when "j", :down then move_cursor_down
        when "k", :up then move_cursor_up
        when "c" then initiate_cancel
        end
      end

      # Onto the last run loaded, which loads the next page, then into the jobs.
      def move_cursor_down
        runs = @board_data.runs
        last = runs.length + @board_data.jobs(runs).length - 1
        return if last.negative?
        return @cursor_index = 0 if @cursor_index.nil?
        return unless @cursor_index < last

        @cursor_index += 1
        @board_data.load_more if @cursor_index == runs.length - 1
      end

      def move_cursor_up
        @cursor_index -= 1 if @cursor_index&.positive?
      end

      def initiate_cancel
        kind, row = under_cursor
        return unless row

        @board_data.cancel_run(row[:id]) if row[:status] == "scheduled"
        @confirm_cancel = [kind, row] if row[:status] == "running"
      end

      # [:run, the run] or [:job, the job row] under the cursor, or none.
      def under_cursor
        runs = @board_data.runs
        return [] unless @cursor_index
        return [:run, runs[@cursor_index]] if @cursor_index < runs.length

        [:job, @board_data.jobs(runs)[@cursor_index - runs.length]]
      end

      def confirm(key)
        cancel(*@confirm_cancel) if key == "y"
        @confirm_cancel = nil if CONFIRMATION_ANSWERS.include?(key)
      end

      def cancel(kind, row) = kind == :job ? @board_data.cancel_job(row[:run][:id]) : @board_data.cancel_run(row[:id])
    end
  end
end
