# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/console_fakes"
require "fun_ci/console/console_session"

# AT-2.1: ConsoleSession answers the renderer's messages with protocol
# messages. It decides what is true; it never draws.
class TestConsoleSession < Minitest::Test
  NOW = Time.utc(2026, 9, 25, 12)

  def setup
    @board_data = ConsoleFakes::BoardData.new([ConsoleFakes.run_row(2, status: "running"), ConsoleFakes.run_row(1)])
    @port = ConsoleFakes::Port.new
    @session = FunCi::Console::ConsoleSession.build(board_data: @board_data, port: @port, clock: -> { NOW })
    @session.start
  end

  def ready = @session.receive('{"t":"ready","v":1,"cols":120,"rows":40}')
  def press(*keys) = keys.each { |key| @session.receive(JSON.generate(t: "key", key: key)) }
  def last = @port.sent.last

  def test_should_greet_the_renderer_when_started
    assert_equal({ "t" => "hello", "v" => 1 }, @port.sent.first)
  end

  def test_should_send_the_board_once_the_renderer_is_ready
    ready

    assert_equal "board", last["t"]
  end

  def test_should_show_every_run_on_the_board
    ready

    assert_equal([2, 1], last["runs"].map { |run| run["id"] })
  end

  def test_should_stamp_the_board_with_the_clock_s_time
    ready

    assert_equal NOW.to_i, last["now"]
  end

  def test_should_carry_the_streak
    ready

    assert_equal 3, last["streak"]
  end

  def test_should_start_with_no_run_under_the_cursor
    ready

    assert_nil last["cursor"]
  end

  def test_should_send_a_board_with_the_cursor_moved_on_j
    ready
    press("j")

    assert_equal 0, last["cursor"]
  end

  def test_should_move_the_cursor_down_on_the_down_key
    ready
    press("j", "down")

    assert_equal 1, last["cursor"]
  end

  def test_should_move_the_cursor_up_on_the_up_key
    ready
    press("j", "j", "up")

    assert_equal 0, last["cursor"]
  end

  def test_should_ask_to_confirm_cancelling_a_running_run
    ready
    press("j", "c")

    assert last["confirming"]
  end

  def test_should_drop_the_confirmation_on_esc
    ready
    press("j", "c", "esc")

    refute last["confirming"]
  end

  def test_should_cancel_the_run_once_confirmed
    ready
    press("j", "c", "y")

    assert_equal [2], @board_data.cancelled
  end

  def test_should_tell_the_renderer_to_quit_on_q
    ready
    press("q")

    assert_equal({ "t" => "quit" }, last)
  end

  def test_should_tell_the_renderer_to_quit_on_ctrl_c
    ready
    press("ctrl_c")

    assert_equal({ "t" => "quit" }, last)
  end

  def test_should_be_finished_once_it_has_quit
    ready
    press("q")

    assert_predicate @session, :finished?
  end

  def test_should_not_be_finished_while_running
    ready

    refute_predicate @session, :finished?
  end

  def test_should_send_no_terminal_escapes
    ready
    press("j", "c")

    refute_includes JSON.generate(@port.sent), "\\u001b"
  end
end
