# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/console_fakes"
require "fun_ci/console/console_session"

# What a board says of hidden jobs (renderer-protocol.md, `board`): that the
# footer asks how to hide one, how many are hidden, and, once the user asks
# to see them, which and how (acceptance-tests.md, AT-13.29 to AT-13.31).
class TestConsoleSessionHiding < Minitest::Test
  # Past the six runs.
  ONTO_THE_JOB = Array.new(7, "j").freeze

  def setup
    @board_data = ConsoleFakes::BoardData.new((1..6).map { |id| ConsoleFakes.run_row(id) })
    @board_data.job_rows = [ConsoleFakes.job_row("soak", status: "failed", id: 7)]
    @port = ConsoleFakes::Port.new
    @session = FunCi::Console::ConsoleSession.build(board_data: @board_data, port: @port, clock: -> { Time.at(0) },
                                                    log: ConsoleFakes::Log.new)
    @session.start
    @session.receive('{"t":"ready","v":1,"cols":120,"rows":24}')
  end

  def test_should_say_the_footer_asks_how_to_hide_the_job
    press(*ONTO_THE_JOB, "h")

    assert board["hiding"]
  end

  def test_should_not_mention_hiding_while_the_footer_asks_nothing
    refute board.key?("hiding")
  end

  def test_should_leave_a_hidden_job_out_of_the_board
    hide_the_job

    refute board.key?("jobs")
  end

  def test_should_say_how_many_jobs_are_hidden
    hide_the_job

    assert_equal 1, board["hidden_jobs"]
  end

  def test_should_not_count_hidden_jobs_while_none_is
    refute board.key?("hidden_jobs")
  end

  # The job section takes no line while it holds no job in view (AT-13.16).
  def test_should_give_the_page_the_job_section_s_lines_while_every_job_is_hidden
    hide_the_job

    assert_equal 6, board["runs"].size
  end

  def test_should_carry_a_hidden_job_once_the_user_asks_to_see_them
    hide_the_job
    press("a")

    assert_equal([%w[soak ignored]], board["jobs"].map { |job| job.values_at("name", "hidden") })
  end

  def test_should_not_say_a_job_in_view_is_hidden
    refute board["jobs"].first.key?("hidden")
  end

  private

  def board = @port.sent.last
  def press(*keys) = keys.each { |key| @session.receive(JSON.generate(t: "key", key: key)) }
  def hide_the_job = press(*ONTO_THE_JOB, "h", "i")
end
