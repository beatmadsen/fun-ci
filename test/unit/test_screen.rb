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

  RUN = { branch: "feat/search", commit_hash: "d4e5f67a3f7c01e9b2d4c6f8a1b3c5d7e9f0a2b4" }.freeze

  def test_the_cancel_prompt_names_the_branch_and_short_sha_of_the_run
    plain = plain_screen_output { |screen| screen.render_footer(confirming: RUN) }
    assert_equal "  Cancel feat/search (d4e5f67)? y / n", plain.lines.first.chomp
  end

  def test_the_cancel_prompt_replaces_the_key_bindings
    refute_match(%r{j/k move}, plain_screen_output { |screen| screen.render_footer(confirming: RUN) })
  end
end

class TestScreenEmptyState < Minitest::Test
  include ScreenOutput

  def test_should_show_no_runs_message
    assert_match(/No runs yet\./, plain_screen_output(&:render_empty_state))
  end

  def test_should_show_the_command_that_sets_fun_ci_up
    assert_match(/fun-ci init --everything/, plain_screen_output(&:render_empty_state))
  end

  def test_should_say_a_commit_starts_a_run
    assert_match(/each commit starts a run/, plain_screen_output(&:render_empty_state))
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
