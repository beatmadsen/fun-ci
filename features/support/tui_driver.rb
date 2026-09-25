# frozen_string_literal: true

require "forwardable"
require_relative "render_capture"
require_relative "run_loop"

# Opens the Admin TUI's run loop against the test database, presses keys, lets
# refresh intervals pass and resizes the terminal, capturing each frame drawn.
class TuiDriver
  extend Forwardable

  TerminalSize = Struct.new(:width, :height)

  def_delegators :@session, :tui, :exited?, :refresh_interval, :terminal_modes

  def initialize(db)
    @db = db
    @capture = RenderCapture.new
    @size = TerminalSize.new(80, nil)
    @session = nil
  end

  def raw_output = @capture.frame
  def plain_output = @capture.plain
  def previous_plain_output = @capture.previous_plain
  def header_line = plain_output.lines.first&.chomp
  def board_lines = plain_output.lines.map(&:chomp)
  def raw_lines = raw_output.split("\r\n")

  def open_tui
    @session ? refresh : open_with
  end

  def open_tui_at_width(width)
    open_with(width: width)
  end

  def open_tui_with_width_provider(initial_width)
    @size.width = initial_width
    open_with(width: initial_width, width_provider: -> { @size.width })
  end

  def provide_width(new_width)
    @size.width = new_width
  end

  def terminal_height=(lines)
    @size.height = lines
  end

  def simulate_resize(new_width)
    tui.resize(new_width)
    refresh
  end

  # The refresh interval the loop is waiting on passes with no key pressed.
  def refresh = advance(nil)
  def press(key) = advance(key)

  # Leaves any confirmation prompt, then quits, as a user would.
  def stop
    return if @session.nil? || exited?

    press(:escape)
    press("q")
    raise "The TUI's run loop did not exit on q" unless exited?
  end

  private

  def open_with(width: 80, width_provider: nil)
    terminal = ScriptedTerminal.new(width_provider: width_provider)
    tui = FunCi::Tui::AdminTui.new(db: @db, output: @capture.io, width: width, terminal_input: terminal,
                                   height_provider: -> { @size.height })
    @session = RunLoop.new(tui, terminal)
    @capture.io.reopen(+"")
    advance(nil)
  end

  def advance(key)
    @session.feed(key)
    @capture.take_frame
  end
end
