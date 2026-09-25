# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/console_fakes"
require "fun_ci/console/console_session"
require "fun_ci/console/console_log"
require "tmpdir"

# AT-2.5: a malformed line or an `error` from the renderer is logged to
# .fun-ci/console.log, and the console carries on.
class TestConsoleProtocolErrors < Minitest::Test
  NOW = Time.utc(2026, 9, 25, 12)

  def setup
    @project = Dir.mktmpdir
    @port = ConsoleFakes::Port.new
    log = FunCi::Console::ConsoleLog.new(project_dir: @project, clock: -> { NOW })
    @session = FunCi::Console::ConsoleSession.build(board_data: ConsoleFakes::BoardData.new([ConsoleFakes.run_row(1)]),
                                                    port: @port, clock: -> { NOW }, log: log)
    @session.receive('{"t":"ready","v":1,"cols":120,"rows":40}')
  end

  def teardown = FileUtils.rm_rf(@project)

  def logged = File.read(File.join(@project, ".fun-ci", "console.log"))

  def test_should_log_a_line_that_is_not_json
    @session.receive("{not json")

    assert_includes logged, "{not json"
  end

  def test_should_log_an_error_the_renderer_reports
    @session.receive('{"t":"error","code":"terminal","detail":"no tty"}')

    assert_includes logged, "no tty"
  end

  def test_should_carry_on_answering_keys_after_a_malformed_line
    @session.receive("{not json")
    @session.receive('{"t":"key","key":"j"}')

    assert_equal 0, @port.sent.last["cursor"]
  end
end
