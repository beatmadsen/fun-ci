# frozen_string_literal: true

require "stringio"
require_relative "render_capture"

# Opens, renders and resizes the Admin TUI against the test database.
class TuiDriver
  attr_reader :tui

  def initialize(db)
    @db = db
    @capture = RenderCapture.new
    @tui = nil
    @current_width = nil
  end

  def output = @capture.io
  def plain_output = @capture.plain
  def raw_output = @capture.io.string
  def header_line = plain_output.lines.first&.chomp
  def board_lines = plain_output.lines.map(&:chomp)

  def open_tui
    return rerender if @tui

    open_with
  end

  def open_tui_at_width(width)
    open_with(width: width)
  end

  def open_tui_with_width_provider(initial_width)
    @current_width = initial_width
    open_with(width: initial_width, width_provider: -> { @current_width })
  end

  def provide_width(new_width)
    @current_width = new_width
  end

  def simulate_resize(new_width)
    @tui.resize(new_width)
    rerender
  end

  def rerender
    @capture.clear
    render
  end

  private

  def open_with(**)
    @capture.renew
    @tui = FunCi::Tui::AdminTui.new(db: @db, output: @capture.io, input: StringIO.new(""), **)
    render
  end

  def render
    @tui.render_once
    @capture.snapshot
  end
end
