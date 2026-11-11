# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/console_fakes"
require "fun_ci/console/key_handler"

# `a` shows the hidden jobs, and hides them again; among them `h` brings one
# back at once (acceptance-tests.md, AT-13.31).
class TestKeyHandlerHiddenJobs < Minitest::Test
  def setup
    @board_data = ConsoleFakes::BoardData.new([ConsoleFakes.run_row(1)])
    @board_data.job_rows = [ConsoleFakes.job_row("soak", status: "failed", id: 7),
                            ConsoleFakes.job_row("mutation", status: "due", id: nil)]
    @handler = FunCi::Console::KeyHandler.new(board_data: @board_data)
  end

  def test_should_show_the_hidden_jobs_when_a_asks_for_them
    press("j", "j", "h", "s", "a")

    assert_equal %w[soak mutation], in_view
  end

  def test_should_hide_them_again_at_the_next_a
    press("j", "j", "h", "s", "a", "a")

    assert_equal %w[mutation], in_view
  end

  def test_should_move_the_cursor_to_the_last_row_in_view_when_a_hides_the_job_under_it
    press("j", "j", "j", "h", "s", "a", "j", "a")

    assert_equal 1, @handler.cursor_index
  end

  # Or the next job hidden would stay in view.
  def test_should_not_take_a_for_a_wish_to_see_hidden_jobs_while_none_is_hidden
    press("a", "j", "j", "h", "s")

    assert_equal %w[mutation], in_view
  end

  def test_should_bring_a_hidden_job_back_at_once_on_h
    press("j", "j", "h", "s", "a", "k", "h")

    assert_empty @board_data.hidden
  end

  def test_should_ask_nothing_before_bringing_a_hidden_job_back
    press("j", "j", "h", "s", "a", "k", "h")

    assert_nil @handler.asking
  end

  def test_should_stop_showing_hidden_jobs_once_none_is_hidden
    press("j", "j", "h", "s", "a", "k", "h", "h", "i")

    assert_equal %w[mutation], in_view
  end

  private

  def press(*keys) = keys.each { |key| @handler.handle_key(key) }
  def in_view = @handler.shown(@board_data.job_rows).map(&:name)
end
