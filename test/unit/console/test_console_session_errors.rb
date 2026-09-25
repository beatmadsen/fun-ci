# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/console_fakes"
require "fun_ci/console/console_session"

# AT-2.5: what the renderer gets wrong is logged, never raised, and the
# session answers the next message as if nothing happened.
class TestConsoleSessionErrors < Minitest::Test
  def setup
    @port = ConsoleFakes::Port.new
    @log = ConsoleFakes::Log.new
    @session = FunCi::Console::ConsoleSession.build(board_data: ConsoleFakes::BoardData.new([ConsoleFakes.run_row(1)]),
                                                    port: @port, clock: -> { Time.at(0) }, log: @log)
    @session.receive('{"t":"ready","v":1,"cols":120,"rows":40}')
  end

  def test_should_log_a_line_that_is_not_json
    @session.receive("{not json")

    assert_equal ['the renderer sent a line that is not JSON: "{not json"'], @log.lines
  end

  def test_should_log_json_that_is_not_a_message
    @session.receive("[1]")

    assert_equal ["the renderer sent a line that is not a message: [1]"], @log.lines
  end

  def test_should_log_an_error_with_its_code_and_detail
    @session.receive('{"t":"error","code":"terminal","detail":"no tty"}')

    assert_equal ["the renderer reported a terminal error: no tty"], @log.lines
  end

  def test_should_log_a_message_of_a_type_it_does_not_know
    @session.receive('{"t":"wave"}')

    assert_equal ['the renderer sent a message of unknown type "wave"'], @log.lines
  end

  def test_should_send_nothing_in_answer_to_a_renderer_error
    sent = @port.sent.size
    @session.receive('{"t":"error","code":"parse","detail":"x"}')

    assert_equal sent, @port.sent.size
  end

  def test_should_answer_the_next_key_after_a_line_that_is_not_json
    @session.receive("{not json")
    @session.receive('{"t":"key","key":"j"}')

    assert_equal 0, @port.sent.last["cursor"]
  end

  def test_should_log_nothing_for_messages_it_understands
    @session.receive('{"t":"key","key":"j"}')

    assert_empty @log.lines
  end
end
