# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/console/board_heartbeat"

# The console log's record of what the console kept showing: every ten
# minutes, how many boards went to the renderer and the newest run on the
# last, so a console that stops showing new runs shows when, and whether
# Ruby still sent boards.
class TestBoardHeartbeat < Minitest::Test
  Port = Struct.new(:written) { def write(message) = written << message }
  Log = Struct.new(:lines) { def write(text) = lines << text }

  def setup
    @now = 1_000
    @port = Port.new([])
    @log = Log.new([])
    @heartbeat = FunCi::Console::BoardHeartbeat.new(@port, log: @log, clock: -> { @now })
  end

  def board(*ids) = { t: "board", runs: ids.map { |id| { id: id } } }

  def test_should_hand_each_message_on_to_the_port
    @heartbeat.write(board(3))

    assert_equal [board(3)], @port.written
  end

  def test_should_log_nothing_before_ten_minutes_have_passed
    @heartbeat.write(board(3))
    @now += 599
    @heartbeat.write(board(3))

    assert_empty @log.lines
  end

  def test_should_log_how_many_boards_went_out_once_ten_minutes_have_passed
    @heartbeat.write(board(3))
    @now += 600
    @heartbeat.write(board(3))

    assert_match(/\A2 boards in the last 600 s/, @log.lines.last)
  end

  def test_should_log_the_newest_run_on_the_last_board
    @heartbeat.write(board(3))
    @now += 600
    @heartbeat.write(board(5, 4))

    assert_match(/the newest run on the last: 5\z/, @log.lines.last)
  end

  def test_should_say_when_the_last_board_showed_no_runs
    @now += 600
    @heartbeat.write(board)

    assert_match(/the last showed no runs\z/, @log.lines.last)
  end

  def test_should_count_only_boards_since_the_last_line
    @now += 600
    @heartbeat.write(board(3))
    @now += 600
    @heartbeat.write(board(3))

    assert_match(/\A1 boards in the last 600 s/, @log.lines.last)
  end

  def test_should_not_count_an_event
    @heartbeat.write({ t: "event", name: "run_passed", run_id: 3 })
    @now += 600
    @heartbeat.write(board(3))

    assert_match(/\A1 boards/, @log.lines.last)
  end
end
