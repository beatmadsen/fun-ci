# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/console_fakes"
require "fun_ci/console/console_session"

# What a board says of hidden branches (renderer-protocol.md, `board`): not
# their rows, how many rows are hidden, and, once the user asks to see them,
# which and how (acceptance-tests.md, AT-13.33).
class TestConsoleSessionHidingBranches < Minitest::Test
  def setup
    @board_data = ConsoleFakes::BoardData.new([ConsoleFakes.run_row(1, status: "failed"), ConsoleFakes.run_row(2)])
    @board_data.job_rows = [ConsoleFakes.job_row("soak", status: "failed", id: 7)]
    @port = ConsoleFakes::Port.new
    @session = FunCi::Console::ConsoleSession.build(board_data: @board_data, port: @port, clock: -> { Time.at(0) },
                                                    log: ConsoleFakes::Log.new)
    @session.start
    @session.receive('{"t":"ready","v":1,"cols":120,"rows":40}')
  end

  def test_should_leave_a_hidden_branch_out_of_the_board
    hide_the_first_branch

    assert_equal([2], board["runs"].map { |run| run["id"] })
  end

  def test_should_count_hidden_branches_and_jobs_together
    hide_the_first_branch
    press("j", "j", "h", "s")

    assert_equal 2, board["hidden_rows"]
  end

  def test_should_carry_a_hidden_branch_once_the_user_asks_to_see_them
    hide_the_first_branch
    press("a")

    assert_equal(["ignored", nil], board["runs"].map { |run| run["hidden"] })
  end

  def test_should_send_no_event_for_a_hidden_branch_s_stage
    @board_data.runs = [ConsoleFakes.fast_stage(1, "running").merge(hidden: "ignored"), ConsoleFakes.run_row(2)]
    @session.refresh
    before = @port.sent.size
    @board_data.runs = [ConsoleFakes.fast_stage(1, "failed").merge(hidden: "ignored"), ConsoleFakes.run_row(2)]
    @session.refresh

    assert_equal(["board"], @port.sent.drop(before).map { |message| message["t"] })
  end

  private

  def board = @port.sent.last
  def press(*keys) = keys.each { |key| @session.receive(JSON.generate(t: "key", key: key)) }
  def hide_the_first_branch = press("j", "h", "i")
end
