# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/console_fakes"
require "fun_ci/console/console_session"

# Each board carries the job section's rows under `jobs`, and each poll
# records failed the jobs whose process died (acceptance-tests.md, AT-13.6, AT-13.14).
class TestConsoleSessionJobs < Minitest::Test
  def setup
    @board_data = ConsoleFakes::BoardData.new([ConsoleFakes.run_row(1)])
    @port = ConsoleFakes::Port.new
    @session = FunCi::Console::ConsoleSession.build(board_data: @board_data, port: @port, clock: -> { Time.at(0) },
                                                    log: ConsoleFakes::Log.new)
    @session.start
    @session.receive('{"t":"ready","v":1,"cols":120,"rows":40}')
  end

  def test_should_send_the_job_section_s_rows_with_the_board
    @board_data.job_rows = [ConsoleFakes.job_row("soak", status: "failed", id: 7)]
    @session.refresh

    assert_equal([%w[soak failed]], @port.sent.last["jobs"].map { |job| job.values_at("name", "status") })
  end

  def test_should_leave_jobs_out_of_a_board_without_any
    @session.refresh

    refute @port.sent.last.key?("jobs")
  end

  def test_should_look_for_dead_jobs_on_every_refresh
    checks_so_far = @board_data.dead_checks.count(:jobs)
    @session.refresh

    assert_equal checks_so_far + 1, @board_data.dead_checks.count(:jobs)
  end
end
