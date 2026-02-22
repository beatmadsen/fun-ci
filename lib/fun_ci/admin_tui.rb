# frozen_string_literal: true

require_relative "board_data"
require_relative "header_animation_manager"
require_relative "row_formatter"
require_relative "screen"
require_relative "spinner"
require_relative "streak_counter"
require "io/console"

module FunCi
  class AdminTui
    FAST_REFRESH = 0.1  # seconds (spinner + timer)
    SLOW_REFRESH = 5.0  # seconds (settled board)
    HEADER_HEIGHT = HeaderAnimationManager::HEADER_HEIGHT

    def initialize(db:, output: $stdout, input: $stdin, width: 80,
                   width_provider: nil, page_size: nil, animation_renderer: nil)
      @board_data = BoardData.new(db, page_size: page_size)
      @screen = Screen.new(output: output, width: width)
      @animation_renderer = animation_renderer
      @input = input
      @width_provider = width_provider
      @spinner = Spinner.new
      @cursor_index = nil
      @running = false
      @confirm_cancel = nil
    end

    def render_once
      update_width_from_provider
      runs = @board_data.runs
      streak = @board_data.streak
      streak_text = StreakCounter.format_text(streak)

      @screen.render_header(streak_text: streak_text)
      (HEADER_HEIGHT - 1).times { @screen.println }

      if runs.empty?
        @screen.render_empty_state
        @screen.render_footer(empty: true)
      else
        rows = runs.map { |run| format_run(run) }
        @screen.render_board(rows, cursor_index: @cursor_index)
        @screen.println
        @screen.render_footer(empty: false, confirming: confirming?)
      end

      @screen.clear_below
      render_animations(runs)
    end

    def run
      @running = true
      @screen.clear

      begin
        setup_raw_mode
        setup_sigwinch_trap
        loop do
          render_frame
          break unless @running
          key = read_key_with_timeout(refresh_interval)
          handle_key(key) if key
        end
      ensure
        restore_terminal
      end
    end

    def resize(new_width)
      @screen.width = new_width
    end

    def confirming?
      !@confirm_cancel.nil?
    end

    def confirmation_run
      @confirm_cancel
    end

    def handle_key(key)
      if @confirm_cancel
        handle_confirm_key(key)
        return
      end

      case key
      when "q"
        @running = false
      when "j", :down
        move_cursor_down
      when "k", :up
        move_cursor_up
      when "c"
        initiate_cancel
      end
    end

    private

    def render_animations(runs)
      return unless @animation_renderer

      @animation_renderer.render(@screen, runs)
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

    def render_frame
      @screen.move_cursor_home
      @spinner.advance!
      render_once
    end

    def refresh_interval
      runs = @board_data.runs
      any_running = runs.any? { |r| r[:status] == "running" }
      any_running ? FAST_REFRESH : SLOW_REFRESH
    end

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

      if @cursor_index > 0
        @cursor_index -= 1
      end
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

    def update_width_from_provider
      return unless @width_provider

      new_width = @width_provider.call
      resize(new_width) if new_width
    end

    def setup_sigwinch_trap
      return unless @width_provider

      @signal_read, @signal_write = IO.pipe
      Signal.trap("WINCH") do
        @signal_write.write_nonblock(".") rescue nil
      end
    end

    def setup_raw_mode
      @input.raw! if @input.respond_to?(:raw!)
    rescue Errno::ENOTTY
      # Not a terminal (testing)
    end

    def restore_terminal
      @input.cooked! if @input.respond_to?(:cooked!)
    rescue Errno::ENOTTY
      # Not a terminal
    end

    def read_key_with_timeout(timeout)
      return nil unless @input.respond_to?(:read_nonblock)

      watched = [@input]
      watched << @signal_read if @signal_read
      ready = IO.select(watched, nil, nil, timeout)
      return nil unless ready

      # Drain signal pipe if it woke us
      if @signal_read && ready[0].include?(@signal_read)
        @signal_read.read_nonblock(1) rescue nil
        return nil unless ready[0].include?(@input)
      end

      byte = @input.read_nonblock(1)
      if byte == "\e"
        # Escape sequence
        seq = @input.read_nonblock(2) rescue ""
        case seq
        when "[A" then :up
        when "[B" then :down
        else :escape
        end
      else
        byte
      end
    rescue IO::WaitReadable, EOFError
      nil
    end
  end
end
