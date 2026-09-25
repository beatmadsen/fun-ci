# frozen_string_literal: true

require_relative "../test_helper"
require_relative "screen_output"

class TestScreenWriteAt < Minitest::Test
  include ScreenOutput

  def test_should_position_cursor_and_write_text
    assert_equal "\e[5;10HBOOM", screen_output(width: 80) { |screen| screen.write_at(5, 10, "BOOM") }
  end

  def test_should_support_top_left_origin
    assert_equal "\e[1;1HX", screen_output(width: 80) { |screen| screen.write_at(1, 1, "X") }
  end

  def test_should_preserve_ansi_codes_in_text
    colored = "\e[31mRED\e[0m"
    assert_equal "\e[3;5H\e[31mRED\e[0m", screen_output(width: 80) { |screen| screen.write_at(3, 5, colored) }
  end
end

class TestScreenSaveRestoreCursor < Minitest::Test
  include ScreenOutput

  def test_should_emit_save_cursor_sequence
    assert_equal "\e[s", screen_output(width: 80, &:save_cursor)
  end

  def test_should_emit_restore_cursor_sequence
    assert_equal "\e[u", screen_output(width: 80, &:restore_cursor)
  end

  def test_save_and_restore_should_bracket_overlay_writes
    raw = screen_output(width: 80) do |screen|
      screen.save_cursor
      screen.write_at(5, 10, "overlay")
      screen.restore_cursor
    end
    assert_equal "\e[s\e[5;10Hoverlay\e[u", raw
  end
end
