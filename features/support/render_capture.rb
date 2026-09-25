# frozen_string_literal: true

require "stringio"

# Holds the stream the TUI renders into and the ANSI-stripped text of the last render.
class RenderCapture
  attr_reader :io, :plain

  def initialize
    @io = StringIO.new
    @plain = nil
  end

  def renew
    @io = StringIO.new
  end

  def clear
    @io.truncate(0)
    @io.rewind
  end

  def snapshot
    @plain = FunCi::Tui::Ansi.strip(@io.string)
  end
end
