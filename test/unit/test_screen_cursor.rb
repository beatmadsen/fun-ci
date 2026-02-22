# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/screen"
require "stringio"

class TestScreenWriteAt < Minitest::Test
  def test_should_position_cursor_and_write_text
    # Given a screen renderer
    output = StringIO.new
    screen = FunCi::Tui::Screen.new(output: output, width: 80)
    # When we write text at a specific position
    screen.write_at(5, 10, "BOOM")
    # Then the output should contain the cursor positioning escape sequence
    assert_equal "\e[5;10HBOOM", output.string
  end

  def test_should_support_row_1_col_1
    output = StringIO.new
    screen = FunCi::Tui::Screen.new(output: output, width: 80)
    screen.write_at(1, 1, "X")
    assert_equal "\e[1;1HX", output.string
  end

  def test_should_preserve_ansi_codes_in_text
    output = StringIO.new
    screen = FunCi::Tui::Screen.new(output: output, width: 80)
    colored = "\e[31mRED\e[0m"
    screen.write_at(3, 5, colored)
    assert_equal "\e[3;5H\e[31mRED\e[0m", output.string
  end
end

class TestScreenSaveRestoreCursor < Minitest::Test
  def test_should_emit_save_cursor_sequence
    output = StringIO.new
    screen = FunCi::Tui::Screen.new(output: output, width: 80)
    screen.save_cursor
    assert_equal "\e[s", output.string
  end

  def test_should_emit_restore_cursor_sequence
    output = StringIO.new
    screen = FunCi::Tui::Screen.new(output: output, width: 80)
    screen.restore_cursor
    assert_equal "\e[u", output.string
  end

  def test_save_and_restore_should_bracket_overlay_writes
    # Given a screen
    output = StringIO.new
    screen = FunCi::Tui::Screen.new(output: output, width: 80)
    # When we use save/write_at/restore pattern
    screen.save_cursor
    screen.write_at(5, 10, "overlay")
    screen.restore_cursor
    # Then the output should contain save, position+text, restore in order
    expected = "\e[s\e[5;10Hoverlay\e[u"
    assert_equal expected, output.string
  end
end
