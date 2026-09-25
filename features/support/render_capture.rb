# frozen_string_literal: true

require "stringio"

# Holds the stream the TUI renders into, split into frames: each frame is what the
# TUI wrote between two waits for a key.
class RenderCapture
  attr_reader :io, :frame, :previous_frame

  def initialize
    @io = StringIO.new
    @frame = ""
    @previous_frame = ""
  end

  def take_frame
    @previous_frame = @frame
    @frame = @io.string.dup
    @io.reopen(+"")
  end

  def plain = strip(@frame)
  def previous_plain = strip(@previous_frame)

  private

  def strip(text) = FunCi::Tui::Ansi.strip(text)
end
