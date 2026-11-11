# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/console_fakes"
require "fun_ci/console/key_handler"

# `h` on a branch asks how to hide it, as on a job; `a` shows the hidden
# branches too, where `h` brings one back (acceptance-tests.md, AT-13.33).
class TestKeyHandlerHidingBranches < Minitest::Test
  def setup
    @board_data = ConsoleFakes::BoardData.new([ConsoleFakes.run_row(1, status: "failed"), ConsoleFakes.run_row(2)])
    @handler = FunCi::Console::KeyHandler.new(board_data: @board_data)
  end

  def test_should_ask_how_to_hide_the_branch_under_the_cursor
    press("j", "h")

    assert_equal :hide, @handler.asking
  end

  def test_should_snooze_the_branch_when_s_answers
    press("j", "h", "s")

    assert_equal [[1, "snoozed"]], @board_data.hidden_runs
  end

  def test_should_ignore_the_branch_when_i_answers
    press("j", "h", "i")

    assert_equal [[1, "ignored"]], @board_data.hidden_runs
  end

  def test_should_leave_a_hidden_branch_out_of_the_rows_in_view
    press("j", "h", "i")

    assert_equal [2], in_view
  end

  def test_should_show_the_hidden_branches_when_a_asks_for_them
    press("j", "h", "i", "a")

    assert_equal [1, 2], in_view
  end

  def test_should_bring_a_hidden_branch_back_at_once_on_h
    press("j", "h", "i", "a", "k", "h")

    assert_empty @board_data.hidden_runs
  end

  def test_should_stop_asking_how_to_hide_a_branch_that_left_the_view
    press("j", "h")
    @handler.follow([ConsoleFakes.run_row(2)], [])

    assert_nil @handler.asking
  end

  private

  def press(*keys) = keys.each { |key| @handler.handle_key(key) }
  def in_view = @handler.shown_runs(@board_data.runs).map { |run| run[:id] }
end
