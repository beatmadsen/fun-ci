# frozen_string_literal: true

require_relative "header_animation_manager"
require_relative "row_formatter"
require_relative "streak_counter"

module FunCi
  class BoardRenderer
    HEADER_HEIGHT = HeaderAnimationManager::HEADER_HEIGHT

    def initialize(screen:, spinner:, animation_renderer:, height_provider:)
      @screen = screen
      @spinner = spinner
      @animation_renderer = animation_renderer
      @height_provider = height_provider
    end

    def render(runs:, streak:, cursor_index:, confirming:)
      render_header_area(runs, streak)

      if runs.empty?
        @screen.render_empty_state
        @screen.render_footer(empty: true)
      else
        rows = runs.map { |run| format_run(run) }
        rows = truncate_rows_to_height(rows)
        @screen.render_board(rows, cursor_index: cursor_index)
        @screen.println unless rows.empty?
        @screen.render_footer(empty: false, confirming: confirming)
      end

      @screen.clear_below
      render_animations(runs)
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

    def has_animation_renderer?
      !!@animation_renderer
    end

    private

    def render_header_area(runs, streak)
      if @animation_renderer
        @screen.write_at(HEADER_HEIGHT + 1, 1, "")
      else
        streak_text = StreakCounter.format_text(streak)
        @screen.render_header(streak_text: streak_text)
        (HEADER_HEIGHT - 1).times { @screen.println }
      end
    end

    def format_run(run)
      opts = {}
      if run[:status] == "running"
        active_stage = run[:stages].find { |s| s[:status] == "running" }
        if active_stage && active_stage[:started_at]
          opts[:elapsed_seconds] = Time.now - Time.parse(active_stage[:started_at])
        end
        opts[:spinner_frame] = @spinner.current_frame
      end
      RowFormatter.format(run, **opts)
    end

    def render_animations(runs)
      return unless @animation_renderer

      @animation_renderer.render(@screen, runs)
    end

    def truncate_rows_to_height(rows)
      return rows unless @height_provider

      height = @height_provider.call
      return rows unless height

      max_rows = [(height - HEADER_HEIGHT - 1) / 2, 0].max
      rows.first(max_rows)
    end
  end
end
