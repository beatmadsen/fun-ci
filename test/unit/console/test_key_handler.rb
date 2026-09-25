# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/console_fakes"
require "fun_ci/console/key_handler"

# What each key does to the cursor, the loaded runs and a cancel.
class TestKeyHandler < Minitest::Test
  def handler_over(*statuses)
    runs = statuses.each_with_index.map { |status, id| ConsoleFakes.run_row(id, status: status) }
    @board_data = ConsoleFakes::BoardData.new(runs)
    FunCi::Console::KeyHandler.new(board_data: @board_data)
  end

  def press(handler, *keys) = keys.each { |key| handler.handle_key(key) }

  def test_should_leave_no_cursor_when_there_are_no_runs
    handler = handler_over
    press(handler, "j")

    assert_nil handler.cursor_index
  end

  def test_should_stop_the_cursor_at_the_last_run
    handler = handler_over("completed", "completed")
    press(handler, "j", "j", "j")

    assert_equal 1, handler.cursor_index
  end

  def test_should_load_more_runs_once_the_cursor_reaches_the_last_loaded
    handler = handler_over("completed", "completed", "completed")
    press(handler, "j", "j", "j")

    assert_equal 1, @board_data.loads
  end

  def test_should_not_load_more_before_the_cursor_reaches_the_last_loaded
    handler = handler_over("completed", "completed", "completed")
    press(handler, "j", "j")

    assert_equal 0, @board_data.loads
  end

  def test_should_cancel_nothing_while_no_run_is_under_the_cursor
    handler = handler_over("scheduled")
    press(handler, "c")

    assert_empty @board_data.cancelled
  end

  def test_should_cancel_a_scheduled_run_at_once
    handler = handler_over("scheduled")
    press(handler, "j", "c")

    assert_equal [0], @board_data.cancelled
  end

  def test_should_ask_before_cancelling_a_running_run
    handler = handler_over("running")
    press(handler, "j", "c")

    assert_equal [[], true], [@board_data.cancelled, handler.confirming?]
  end

  def test_should_not_quit_on_q_while_confirming
    handler = handler_over("running")
    press(handler, "j", "c")

    assert_nil handler.handle_key("q")
  end

  def test_should_keep_the_cursor_on_the_first_run_on_k
    handler = handler_over("completed", "completed")
    press(handler, "j", "k", "k")

    assert_equal 0, handler.cursor_index
  end

  def test_should_drop_the_confirmation_on_n
    handler = handler_over("running")
    press(handler, "j", "c", "n")

    assert_equal [[], false], [@board_data.cancelled, handler.confirming?]
  end

  def test_should_do_nothing_on_c_over_a_finished_run
    handler = handler_over("completed")
    press(handler, "j", "c")

    assert_equal [[], false], [@board_data.cancelled, handler.confirming?]
  end
end
