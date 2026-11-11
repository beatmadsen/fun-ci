# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/console_fakes"
require "fun_ci/console/key_handler"

# `h` on a job asks how to hide it: `s` snoozes it, `i` ignores it, and the
# cursor stays on a row in view (acceptance-tests.md, AT-13.29, AT-13.30).
class TestKeyHandlerHiding < Minitest::Test
  def setup
    @board_data = ConsoleFakes::BoardData.new([ConsoleFakes.run_row(1)])
    @board_data.job_rows = [ConsoleFakes.job_row("soak", status: "failed", id: 7),
                            ConsoleFakes.job_row("mutation", status: "due", id: nil)]
    @handler = FunCi::Console::KeyHandler.new(board_data: @board_data)
  end

  def test_should_ask_how_to_hide_the_job_under_the_cursor
    press("j", "j", "h")

    assert_equal :hide, @handler.asking
  end

  def test_should_ask_nothing_on_h_without_a_cursor
    press("h")

    assert_nil @handler.asking
  end

  def test_should_not_say_a_cancel_is_being_confirmed_while_it_asks_how_to_hide
    press("j", "j", "h")

    refute_predicate @handler, :confirming?
  end

  def test_should_snooze_the_job_when_s_answers
    press("j", "j", "h", "s")

    assert_equal [%w[soak snoozed]], @board_data.hidden
  end

  def test_should_ignore_the_job_when_i_answers
    press("j", "j", "h", "i")

    assert_equal [%w[soak ignored]], @board_data.hidden
  end

  def test_should_hide_nothing_when_n_answers
    press("j", "j", "h", "n")

    assert_empty @board_data.hidden
  end

  def test_should_stop_asking_once_answered
    press("j", "j", "h", "s")

    assert_nil @handler.asking
  end

  def test_should_stop_asking_when_n_answers
    press("j", "j", "h", "n")

    assert_nil @handler.asking
  end

  def test_should_stop_asking_at_escape
    press("j", "j", "h", :escape)

    assert_nil @handler.asking
  end

  # `y` answers a cancel, and hides nothing.
  def test_should_keep_asking_at_a_key_that_is_no_answer
    press("j", "j", "h", "y")

    assert_equal :hide, @handler.asking
  end

  # Ctrl-C comes as `q`, and quits whatever is asked.
  def test_should_quit_at_q_while_it_asks
    press("j", "j", "h")

    assert_equal :quit, @handler.handle_key("q")
  end

  def test_should_leave_a_hidden_job_out_of_the_rows_in_view
    press("j", "j", "h", "s")

    assert_equal %w[mutation], in_view
  end

  def test_should_stop_the_cursor_at_the_last_job_in_view
    press("j", "j", "h", "s", "j", "j")

    assert_equal 1, @handler.cursor_index
  end

  def test_should_move_the_cursor_to_the_last_row_when_the_job_under_it_leaves_the_view
    press("j", "j", "j", "h", "s")

    assert_equal 1, @handler.cursor_index
  end

  def test_should_drop_the_cursor_when_the_only_row_leaves_the_view
    @board_data.runs = []
    @board_data.job_rows = [ConsoleFakes.job_row("soak")]
    press("j", "h", "i")

    assert_nil @handler.cursor_index
  end

  private

  def press(*keys) = keys.each { |key| @handler.handle_key(key) }
  def in_view = @handler.shown(@board_data.job_rows).map(&:name)
end
