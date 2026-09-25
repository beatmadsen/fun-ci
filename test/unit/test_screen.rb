# frozen_string_literal: true

require_relative "../test_helper"
require_relative "screen_output"

class TestScreenHeader < Minitest::Test
  include ScreenOutput

  def test_should_show_fun_ci_in_header
    assert_match(/fun-ci/, screen_output { |screen| screen.render_header(streak_text: nil) })
  end

  def test_should_show_streak_in_header
    plain = plain_screen_output { |screen| screen.render_header(streak_text: "7 in a row!") }
    assert_match(/7 in a row!/, plain)
  end

  def test_should_use_charcoal_background
    raw = screen_output { |screen| screen.render_header(streak_text: nil) }
    assert_match(/\e\[48;5;236m/, raw, "Header should have charcoal background")
  end
end

class TestScreenFooter < Minitest::Test
  include ScreenOutput

  def test_should_show_full_key_bindings
    plain = plain_screen_output { |screen| screen.render_footer(empty: false) }
    assert_match(%r{j/k move}, plain)
    assert_match(/c cancel/, plain)
    assert_match(/q quit/, plain)
  end

  def test_should_show_only_quit_when_empty
    plain = plain_screen_output { |screen| screen.render_footer(empty: true) }
    assert_match(/q quit/, plain)
    refute_match(%r{j/k move}, plain)
    refute_match(/c cancel/, plain)
  end

  def test_should_be_dim
    raw = screen_output { |screen| screen.render_footer(empty: false) }
    assert_match(/\e\[2m/, raw, "Footer should be dim")
  end

  def test_should_show_confirmation_prompt_when_confirming
    plain = plain_screen_output { |screen| screen.render_footer(confirming: true) }
    assert_match(%r{cancel.*\?.*y/n}i, plain,
                 "Footer should show confirmation prompt with y/n when confirming")
    refute_match(%r{j/k move}, plain,
                 "Normal key bindings should be hidden during confirmation")
  end
end

class TestScreenEmptyState < Minitest::Test
  include ScreenOutput

  def test_should_show_no_runs_message
    assert_match(/No runs yet\./, plain_screen_output(&:render_empty_state))
  end

  def test_should_show_trigger_command
    assert_match(/fun-ci trigger HEAD/, plain_screen_output(&:render_empty_state))
  end

  def test_should_show_hook_command
    assert_match(/fun-ci install-hook pre-push/, plain_screen_output(&:render_empty_state))
  end
end

class TestScreenBoard < Minitest::Test
  include ScreenOutput

  def test_should_render_rows
    rows = ["  a3f7c01  main  Build 0.3s  PASSED"]
    raw = screen_output(width: 80) { |screen| screen.render_board(rows, cursor_index: nil) }
    assert_match(/a3f7c01/, raw)
  end

  def test_should_highlight_selected_row
    rows = ["  row0  data", "  row1  data"]
    plain = plain_screen_output(width: 80) { |screen| screen.render_board(rows, cursor_index: 0) }
    assert_match(/>\s*row0/, plain, "Selected row should have cursor marker")
  end

  def test_should_not_show_cursor_when_nil
    rows = ["  row0  data"]
    plain = plain_screen_output(width: 80) { |screen| screen.render_board(rows, cursor_index: nil) }
    refute_match(/>/, plain, "No cursor marker when cursor_index is nil")
  end
end
