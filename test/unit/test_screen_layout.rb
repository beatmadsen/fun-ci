# frozen_string_literal: true

require_relative "../test_helper"
require_relative "screen_output"

class TestScreenResize < Minitest::Test
  include ScreenOutput

  CLEAR_SCREEN = "\e[2J"

  def test_should_render_header_at_new_width_after_width_is_updated
    header = header_after_resizing_to(100)
    assert_equal 100, header.length, "Header should be 100 chars wide but was #{header.length}"
  end

  def test_should_clear_screen_when_width_changes
    raw = screen_output { |screen| screen.width = 100 }
    assert_includes raw, CLEAR_SCREEN, "Should clear screen when width changes"
  end

  def test_should_not_clear_screen_when_width_is_set_to_same_value
    raw = screen_output { |screen| screen.width = 60 }
    refute_includes raw, CLEAR_SCREEN, "Should not clear screen when width unchanged"
  end

  def test_should_clear_screen_when_height_changes
    assert_includes output_of_height_change(40, 20), CLEAR_SCREEN, "Should clear screen when height changes"
  end

  def test_should_not_clear_screen_when_height_is_set_to_same_value
    refute_includes output_of_height_change(40, 40), CLEAR_SCREEN, "Should not clear screen when height unchanged"
  end

  private

  def header_after_resizing_to(width)
    output = StringIO.new
    screen = FunCi::Tui::Screen.new(output: output, width: 60)
    screen.width = width
    discard(output)
    screen.render_header(streak_text: nil)
    FunCi::Tui::Ansi.strip(output.string).lines.first.chomp
  end

  def output_of_height_change(from, to)
    output = StringIO.new
    screen = FunCi::Tui::Screen.new(output: output, width: 60)
    screen.height = from
    discard(output)
    screen.height = to
    output.string
  end
end

class TestScreenLineEndings < Minitest::Test
  include ScreenOutput

  def test_should_use_carriage_return_line_feed_endings_for_raw_terminal_compatibility
    raw = screen_output(&:render_empty_state)
    newline_positions = (0...raw.length).select { |i| raw[i] == "\n" }
    assert newline_positions.any?, "Output should contain newlines"
    newline_positions.each do |pos|
      assert_equal "\r", raw[pos - 1],
                   "Newline at position #{pos} should be preceded by \\r for raw terminal compatibility"
    end
  end

  def test_should_erase_to_end_of_line_on_every_println_to_prevent_stale_content
    raw = screen_output { |screen| ["Hello", "", "World"].each { |text| screen.println(text) } }
    content_lines = raw.split("\r\n", -1)[0...-1]
    assert_equal 3, content_lines.length, "Should have three printed lines"
    content_lines.each_with_index do |line, i|
      assert line.end_with?("\e[K"),
             "Line #{i} should end with ESC[K (erase to end of line) but was: #{line.inspect}"
    end
  end
end

class TestScreenClearBelow < Minitest::Test
  include ScreenOutput

  def test_should_emit_erase_below_cursor_sequence
    assert_equal "\e[J", screen_output(&:clear_below),
                 "clear_below should emit ESC[J to erase stale content below the cursor"
  end
end
