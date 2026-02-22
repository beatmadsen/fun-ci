# frozen_string_literal: true

require_relative "board_data"
require_relative "board_renderer"
require_relative "key_handler"
require_relative "screen"
require_relative "spinner"
require_relative "terminal_input"
require "io/console"

module FunCi
  class AdminTui
    FAST_REFRESH = 0.1  # seconds (spinner + timer)
    SLOW_REFRESH = 5.0  # seconds (settled board)

    def initialize(db:, output: $stdout, input: $stdin, width: 80,
                   width_provider: nil, height_provider: nil,
                   page_size: nil, animation_renderer: nil)
      @board_data = BoardData.new(db, page_size: page_size)
      @terminal_input = TerminalInput.new(input: input, width_provider: width_provider)
      @key_handler = KeyHandler.new(board_data: @board_data)
      @renderer = BoardRenderer.new(
        screen: Screen.new(output: output, width: width),
        spinner: Spinner.new,
        animation_renderer: animation_renderer,
        height_provider: height_provider
      )
    end

    def render_once
      update_width_from_provider
      @renderer.render(
        runs: @board_data.runs,
        streak: @board_data.streak,
        cursor_index: @key_handler.cursor_index,
        confirming: @key_handler.confirming?
      )
    end

    def run
      @renderer.clear

      begin
        @terminal_input.setup_raw_mode
        @terminal_input.setup_signal_trap
        loop do
          @renderer.begin_frame
          render_once
          key = @terminal_input.read_key_with_timeout(refresh_interval)
          break if key && @key_handler.handle_key(key) == :quit
        end
      ensure
        @terminal_input.restore_terminal
      end
    end

    def resize(new_width)
      @renderer.resize(new_width)
    end

    def confirming?
      @key_handler.confirming?
    end

    def confirmation_run
      @key_handler.confirmation_run
    end

    def handle_key(key)
      @key_handler.handle_key(key)
    end

    private

    def refresh_interval
      return FAST_REFRESH if @renderer.has_animation_renderer?

      runs = @board_data.runs
      any_running = runs.any? { |r| r[:status] == "running" }
      any_running ? FAST_REFRESH : SLOW_REFRESH
    end

    def update_width_from_provider
      new_width = @terminal_input.check_width
      @renderer.resize(new_width) if new_width
    end
  end
end
