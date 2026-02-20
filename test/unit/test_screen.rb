# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/screen"
require "fun_ci/ansi"
require "stringio"

class TestScreenHeader < Minitest::Test
  def test_should_show_fun_ci_in_header
    # Given a screen renderer
    output = StringIO.new
    screen = FunCi::Screen.new(output: output, width: 60)
    # When we render the header
    screen.render_header(streak_text: nil)
    # Then the output should contain "fun-ci"
    assert_match(/fun-ci/, output.string)
  end

  def test_should_show_streak_in_header
    output = StringIO.new
    screen = FunCi::Screen.new(output: output, width: 60)
    screen.render_header(streak_text: "7 in a row!")
    plain = FunCi::Ansi.strip(output.string)
    assert_match(/7 in a row!/, plain)
  end

  def test_should_use_charcoal_background
    output = StringIO.new
    screen = FunCi::Screen.new(output: output, width: 60)
    screen.render_header(streak_text: nil)
    assert_match(/\e\[48;5;236m/, output.string, "Header should have charcoal background")
  end
end

class TestScreenFooter < Minitest::Test
  def test_should_show_full_key_bindings
    output = StringIO.new
    screen = FunCi::Screen.new(output: output, width: 60)
    screen.render_footer(empty: false)
    plain = FunCi::Ansi.strip(output.string)
    assert_match(/j\/k move/, plain)
    assert_match(/c cancel/, plain)
    assert_match(/q quit/, plain)
  end

  def test_should_show_only_quit_when_empty
    output = StringIO.new
    screen = FunCi::Screen.new(output: output, width: 60)
    screen.render_footer(empty: true)
    plain = FunCi::Ansi.strip(output.string)
    assert_match(/q quit/, plain)
    refute_match(/j\/k move/, plain)
    refute_match(/c cancel/, plain)
  end

  def test_should_be_dim
    output = StringIO.new
    screen = FunCi::Screen.new(output: output, width: 60)
    screen.render_footer(empty: false)
    assert_match(/\e\[2m/, output.string, "Footer should be dim")
  end
end

class TestScreenEmptyState < Minitest::Test
  def test_should_show_no_runs_message
    output = StringIO.new
    screen = FunCi::Screen.new(output: output, width: 60)
    screen.render_empty_state
    plain = FunCi::Ansi.strip(output.string)
    assert_match(/No runs yet\./, plain)
  end

  def test_should_show_trigger_command
    output = StringIO.new
    screen = FunCi::Screen.new(output: output, width: 60)
    screen.render_empty_state
    plain = FunCi::Ansi.strip(output.string)
    assert_match(/fun-ci trigger HEAD/, plain)
  end

  def test_should_show_hook_command
    output = StringIO.new
    screen = FunCi::Screen.new(output: output, width: 60)
    screen.render_empty_state
    plain = FunCi::Ansi.strip(output.string)
    assert_match(/fun-ci install-hook pre-push/, plain)
  end
end

class TestScreenResize < Minitest::Test
  def test_should_render_header_at_new_width_after_width_is_updated
    # Given a screen at width 60
    output = StringIO.new
    screen = FunCi::Screen.new(output: output, width: 60)
    # When width is updated to 100
    screen.width = 100
    output.truncate(0)
    output.rewind
    screen.render_header(streak_text: nil)
    plain = FunCi::Ansi.strip(output.string)
    header = plain.lines.first.chomp
    # Then the header should fill 100 columns
    assert_equal 100, header.length,
      "Header should be 100 chars wide but was #{header.length}"
  end

  def test_should_clear_screen_when_width_changes
    # Given a screen at width 60
    output = StringIO.new
    screen = FunCi::Screen.new(output: output, width: 60)
    # When width is changed to 100
    screen.width = 100
    # Then output should contain a clear-screen sequence
    assert_includes output.string, "\e[2J",
      "Should clear screen when width changes"
  end

  def test_should_not_clear_screen_when_width_is_set_to_same_value
    # Given a screen at width 60
    output = StringIO.new
    screen = FunCi::Screen.new(output: output, width: 60)
    # When width is set to the same value
    screen.width = 60
    # Then no clear-screen sequence should be emitted
    refute_includes output.string, "\e[2J",
      "Should not clear screen when width unchanged"
  end
end

class TestScreenLineEndings < Minitest::Test
  def test_should_use_carriage_return_line_feed_endings_for_raw_terminal_compatibility
    # Given a screen renderer
    output = StringIO.new
    screen = FunCi::Screen.new(output: output, width: 60)
    # When we render the empty state (multiple lines)
    screen.render_empty_state
    raw = output.string
    # Then every newline should be preceded by a carriage return (\r\n)
    # so the cursor returns to column 1 in raw terminal mode
    newline_positions = (0...raw.length).select { |i| raw[i] == "\n" }
    assert newline_positions.any?, "Output should contain newlines"
    newline_positions.each do |pos|
      assert_equal "\r", raw[pos - 1],
        "Newline at position #{pos} should be preceded by \\r for raw terminal compatibility"
    end
  end

  def test_should_erase_to_end_of_line_on_every_println_to_prevent_stale_content
    # Given a screen renderer
    output = StringIO.new
    screen = FunCi::Screen.new(output: output, width: 60)
    # When we print several lines (some with content, some blank)
    screen.println("Hello")
    screen.println("")
    screen.println("World")
    raw = output.string
    # Then each line should contain the erase-to-end-of-line sequence (\e[K)
    # before the \r\n terminator, so shorter lines clear stale content
    lines = raw.split("\r\n", -1)
    content_lines = lines[0...-1] # drop trailing empty element from split
    assert_equal 3, content_lines.length, "Should have three printed lines"
    content_lines.each_with_index do |line, i|
      assert line.end_with?("\e[K"),
        "Line #{i} should end with ESC[K (erase to end of line) but was: #{line.inspect}"
    end
  end
end

class TestScreenClearBelow < Minitest::Test
  def test_should_emit_erase_below_cursor_sequence
    # Given a screen renderer
    output = StringIO.new
    screen = FunCi::Screen.new(output: output, width: 60)
    # When we call clear_below
    screen.clear_below
    # Then the output should contain the "erase from cursor to end of screen" escape sequence
    assert_equal "\e[J", output.string,
      "clear_below should emit ESC[J to erase stale content below the cursor"
  end
end

class TestScreenBoard < Minitest::Test
  def test_should_render_rows
    output = StringIO.new
    screen = FunCi::Screen.new(output: output, width: 80)
    rows = ["  a3f7c01  main  Build 0.3s  PASSED"]
    screen.render_board(rows, cursor_index: nil)
    assert_match(/a3f7c01/, output.string)
  end

  def test_should_highlight_selected_row
    output = StringIO.new
    screen = FunCi::Screen.new(output: output, width: 80)
    rows = ["  row0  data", "  row1  data"]
    screen.render_board(rows, cursor_index: 0)
    # The selected row should have a marker or highlight
    assert_match(/>\s*row0/, FunCi::Ansi.strip(output.string), "Selected row should have cursor marker")
  end

  def test_should_not_show_cursor_when_nil
    output = StringIO.new
    screen = FunCi::Screen.new(output: output, width: 80)
    rows = ["  row0  data"]
    screen.render_board(rows, cursor_index: nil)
    refute_match(/>/, FunCi::Ansi.strip(output.string), "No cursor marker when cursor_index is nil")
  end
end
