# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/console_fakes"
require "fun_ci/console/key_handler"

# The cursor stays on the row it is on when the rows move under it, and the
# footer stops asking about a row that left (design.md, The console;
# acceptance-tests.md, AT-13.32).
class TestKeyHandlerFollows < Minitest::Test
  SOAK = ConsoleFakes.job_row("soak", status: "failed", id: 7)
  AUDIT = ConsoleFakes.job_row("audit", status: "running", id: 8)
  TIDY = ConsoleFakes.job_row("tidy", status: "due", id: nil)
  FIRST = ConsoleFakes.run_row(1, status: "running")
  SECOND = ConsoleFakes.run_row(2)

  def setup
    @board_data = ConsoleFakes::BoardData.new([FIRST, SECOND])
    @board_data.job_rows = [SOAK, AUDIT, TIDY]
    @handler = FunCi::Console::KeyHandler.new(board_data: @board_data)
  end

  def test_should_keep_the_cursor_on_its_job_when_the_jobs_reorder
    press("j", "j", "j", "j")
    @handler.follow([FIRST, SECOND], [AUDIT, TIDY, SOAK])

    assert_equal 2, @handler.cursor_index
  end

  def test_should_keep_the_cursor_on_its_branch_when_the_branches_reorder
    press("j")
    @handler.follow([SECOND, FIRST], [SOAK, AUDIT, TIDY])

    assert_equal 1, @handler.cursor_index
  end

  def test_should_keep_the_cursor_on_its_job_when_a_key_finds_the_jobs_reordered
    press("j", "j", "j", "j")
    @board_data.job_rows = [AUDIT, TIDY, SOAK]
    press("j")

    assert_equal 3, @handler.cursor_index
  end

  def test_should_keep_asking_while_the_job_asked_about_moves
    press("j", "j", "j", "j", "h")
    @handler.follow([FIRST, SECOND], [AUDIT, TIDY, SOAK])

    assert_equal :hide, @handler.asking
  end

  def test_should_stop_asking_how_to_hide_a_job_that_left_the_view
    press("j", "j", "j", "h")
    @handler.follow([FIRST, SECOND], [AUDIT, TIDY])

    assert_nil @handler.asking
  end

  def test_should_hide_nothing_when_the_job_asked_about_left_before_the_answer
    press("j", "j", "j", "h")
    @board_data.job_rows = [AUDIT, TIDY]
    press("i")

    assert_empty @board_data.hidden
  end

  def test_should_stop_asking_to_cancel_a_job_that_stopped_running
    press("j", "j", "j", "j", "c")
    @handler.follow([FIRST, SECOND], [SOAK, ConsoleFakes.job_row("audit", status: "failed", id: 8), TIDY])

    assert_nil @handler.asking
  end

  def test_should_stop_asking_to_cancel_a_branch_whose_newer_run_replaced_the_one_asked_about
    press("j", "c")
    @handler.follow([ConsoleFakes.run_row(1, status: "running").merge(id: 3), SECOND], [SOAK, AUDIT, TIDY])

    assert_nil @handler.asking
  end

  def test_should_cancel_nothing_when_the_job_asked_about_stopped_running_before_the_answer
    press("j", "j", "j", "j", "c")
    @board_data.job_rows = [SOAK, ConsoleFakes.job_row("audit", status: "failed", id: 8), TIDY]
    press("y")

    assert_empty @board_data.cancelled
  end

  private

  def press(*keys) = keys.each { |key| @handler.handle_key(key) }
end
