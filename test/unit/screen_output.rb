# frozen_string_literal: true

require "fun_ci/tui/screen"
require "fun_ci/tui/ansi"
require "stringio"

module ScreenOutput
  def screen_output(width: 60)
    output = StringIO.new
    yield FunCi::Tui::Screen.new(output: output, width: width)
    output.string
  end

  def plain_screen_output(width: 60, &)
    FunCi::Tui::Ansi.strip(screen_output(width: width, &))
  end

  def discard(output)
    output.truncate(0)
    output.rewind
  end
end
