# frozen_string_literal: true

require_relative "board"
require_relative "header_animation_manager"
require_relative "row_formatter"
require_relative "../console/streak_counter"

module FunCi
  module Tui
    class BoardRenderer
      HEADER_HEIGHT = HeaderAnimationManager::HEADER_HEIGHT

      def initialize(screen:, spinner:, animation_renderer:, height_provider:)
        @screen = screen
        @spinner = spinner
        @animation_renderer = animation_renderer
        @height_provider = height_provider
      end

      def render(board)
        update_height
        render_header_area(board.runs, board.streak)
        board.runs.empty? ? render_empty : render_rows(board)
        @screen.clear_below
        render_animations(board.runs)
      end

      def begin_frame
        @screen.move_cursor_home
        @spinner.advance!
      end

      def clear
        @screen.clear
      end

      def resize(new_width)
        @screen.width = new_width
      end

      def animation_renderer?
        !!@animation_renderer
      end

      private

      def render_header_area(runs, streak)
        if @animation_renderer
          @screen.write_at(HEADER_HEIGHT + 1, 1, "")
        else
          streak_text = Console::StreakCounter.format_text(streak)
          @screen.render_header(streak_text: streak_text)
          (HEADER_HEIGHT - 1).times { @screen.println }
        end
      end

      def render_empty
        @screen.render_empty_state
        @screen.render_footer(empty: true)
      end

      def render_rows(board)
        rows = truncate_rows_to_height(board.runs.map { |run| format_run(run, board.now) })
        @screen.render_board(rows, cursor_index: board.cursor_index)
        @screen.println unless rows.empty?
        @screen.render_footer(empty: false, confirming: confirming_run(board))
      end

      def confirming_run(board)
        board.runs[board.cursor_index] if board.confirming && board.cursor_index
      end

      def format_run(run, now)
        return RowFormatter.format(run, now: now) unless run[:status] == "running"

        RowFormatter.format(run, now: now, spinner_frame: @spinner.current_frame,
                                 elapsed_seconds: elapsed_seconds(run, now))
      end

      def elapsed_seconds(run, now)
        active_stage = run[:stages].find { |s| s[:status] == "running" }
        now - Time.parse(active_stage[:started_at]) if active_stage&.dig(:started_at)
      end

      def render_animations(runs)
        return unless @animation_renderer

        @animation_renderer.render(@screen, runs)
      end

      def update_height
        return unless @height_provider

        height = @height_provider.call
        @screen.height = height if height
      end

      def truncate_rows_to_height(rows)
        height = @screen.height
        return rows unless height

        # Line budget: N rows consume 2N-1 lines (row + separator between rows).
        # Remaining height after header, post-board separator, and footer:
        #   available = height - HEADER_HEIGHT - 2
        # Solving 2N - 1 <= available gives N <= (available) / 2.
        max_rows = [(height - HEADER_HEIGHT - 2) / 2, 0].max
        rows.first(max_rows)
      end
    end
  end
end
