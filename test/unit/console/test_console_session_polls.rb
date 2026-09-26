# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/console_fakes"
require "fun_ci/console/console_session"

# AT-2.3: each time the session reads the runs, by a poll or after a key, it
# sends an event for each stage that changed since the last read, then the
# board.
class TestConsoleSessionPolls < Minitest::Test
  def setup
    @board_data = ConsoleFakes::BoardData.new([ConsoleFakes.fast_stage(2, "running")])
    @port = ConsoleFakes::Port.new
    @session = FunCi::Console::ConsoleSession.build(board_data: @board_data, port: @port, clock: -> { Time.at(0) },
                                                    log: ConsoleFakes::Log.new)
    @session.start
    @session.receive('{"t":"ready","v":1,"cols":120,"rows":40}')
  end

  def test_should_send_a_fresh_board_on_refresh
    @board_data.runs = [ConsoleFakes.run_row(5)]
    @session.refresh

    assert_equal([5], @port.sent.last["runs"].map { |run| run["id"] })
  end

  def test_should_look_for_dead_slow_suites_on_every_refresh
    checks_so_far = @board_data.dead_checks

    @session.refresh

    assert_equal checks_so_far + 1, @board_data.dead_checks, "each poll records slow suites that died (AT-8.3)"
  end

  def test_should_send_a_stage_s_event_before_the_board_on_refresh
    @board_data.runs = [ConsoleFakes.fast_stage(2, "failed")]
    @session.refresh

    assert_equal(%w[event board], @port.sent.last(2).map { |message| message["t"] })
  end

  def test_should_send_the_event_a_key_press_reveals
    @board_data.runs = [ConsoleFakes.fast_stage(2, "failed")]
    @session.receive('{"t":"key","key":"j"}')

    assert_equal "stage_failed", @port.sent[-2]["name"]
  end

  def test_should_page_the_board_for_the_rows_of_a_resize
    @board_data.runs = (1..6).map { |id| ConsoleFakes.run_row(id) }
    @session.receive('{"t":"resize","cols":120,"rows":24}')

    assert_equal 4, @port.sent.last["runs"].size
  end

  def test_should_send_nothing_on_refresh_before_the_renderer_is_ready
    port = ConsoleFakes::Port.new
    session = FunCi::Console::ConsoleSession.build(board_data: @board_data, port: port, clock: -> { Time.at(0) },
                                                   log: ConsoleFakes::Log.new)
    session.start
    session.refresh

    assert_equal(["hello"], port.sent.map { |message| message["t"] })
  end
end
