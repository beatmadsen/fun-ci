# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/console_fakes"
require "fun_ci/console/key_handler"

# The cursor moves on from the last branch into the jobs, and `c` cancels a
# running job once the user confirms (acceptance-tests.md, AT-13.15).
class TestKeyHandlerJobs < Minitest::Test
  def setup
    @board_data = ConsoleFakes::BoardData.new([ConsoleFakes.run_row(1)])
    @board_data.job_rows = [ConsoleFakes.job_row("soak", status: "running", id: 7),
                            ConsoleFakes.job_row("mutation", status: "due", id: nil)]
    @handler = FunCi::Console::KeyHandler.new(board_data: @board_data)
  end

  def test_should_move_the_cursor_from_the_last_branch_to_the_first_job
    press("j", "j")

    assert_equal 1, @handler.cursor_index
  end

  def test_should_stop_the_cursor_at_the_last_job
    press("j", "j", "j", "j")

    assert_equal 2, @handler.cursor_index
  end

  def test_should_ask_before_cancelling_a_running_job
    press("j", "j", "c")

    assert_predicate @handler, :confirming?
  end

  def test_should_cancel_the_running_job_s_run_once_confirmed
    press("j", "j", "c", "y")

    assert_equal ["job 7"], @board_data.cancelled
  end

  def test_should_do_nothing_on_c_over_a_job_that_is_not_running
    press("j", "j", "j", "c")

    refute_predicate @handler, :confirming?
  end

  def test_should_reach_the_jobs_when_there_are_no_runs
    @board_data.runs = []
    press("j")

    assert_equal 0, @handler.cursor_index
  end

  private

  def press(*keys) = keys.each { |key| @handler.handle_key(key) }
end
