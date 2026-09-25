# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/console_fakes"
require "fun_ci/console/view"
require "fun_ci/console/key_handler"

# AT-2.4: the board carries one page of runs, as many as the terminal's rows
# fit, scrolled so the run under the cursor is on it.
class TestView < Minitest::Test
  RUNS = (1..6).map { |id| ConsoleFakes.run_row(id) }

  def setup
    @board_data = ConsoleFakes::BoardData.new(RUNS)
    @view = FunCi::Console::View.new(key_handler: FunCi::Console::KeyHandler.new(board_data: @board_data))
  end

  def page(more: false) = @view.page(RUNS, more: more)
  def ids = page[:runs].map { |run| run[:id] }
  def press(times) = times.times { @view.press("j") }

  def test_should_fit_two_rows_per_run_below_the_header_and_footer
    assert_equal 4, @view.resize(24)
  end

  def test_should_fit_no_run_on_a_terminal_shorter_than_the_header_and_footer
    assert_equal 0, @view.resize(10)
  end

  def test_should_show_the_first_page_while_no_run_is_under_the_cursor
    @view.resize(24)

    assert_equal [1, 2, 3, 4], ids
  end

  def test_should_scroll_so_the_run_under_the_cursor_is_on_the_page
    @view.resize(24)
    press(5)

    assert_equal [2, 3, 4, 5], ids
  end

  def test_should_point_the_cursor_into_the_page
    @view.resize(24)
    press(5)

    assert_equal 3, page[:cursor]
  end

  def test_should_have_no_cursor_before_the_first_move
    @view.resize(24)

    assert_nil page[:cursor]
  end

  def test_should_show_no_run_and_no_cursor_when_none_fit
    @view.resize(10)
    press(2)

    assert_equal({ cursor: nil, runs: [] }, page.slice(:cursor, :runs))
  end

  def test_should_say_there_are_more_when_loaded_runs_go_past_the_page
    @view.resize(24)

    assert page[:has_more]
  end

  def test_should_say_there_are_more_when_the_store_holds_more
    @view.resize(40)

    assert page(more: true)[:has_more]
  end

  def test_should_say_there_are_none_when_the_page_ends_at_the_last_run
    @view.resize(40)

    refute page[:has_more]
  end

  def test_should_say_whether_a_cancel_is_being_confirmed
    @view.resize(24)
    press(1)

    refute page[:confirming]
  end
end
