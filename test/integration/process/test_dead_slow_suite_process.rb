# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/console/board_data"

# AT-8.3 with real processes: the console asks the operating system whether
# the slow suite's process still exists.
class TestDeadSlowSuiteProcess < Minitest::Test
  include DatabaseTestSetup
  include PipelineTestHelpers

  def setup
    setup_test_db
    @run_id = create_pipeline_run("abc1234", "main", "running")
    %w[lint build fast].each { |stage| create_stage_job(@run_id, stage, "running", "completed") }
    create_stage_job(@run_id, "slow", "running")
  end

  def teardown
    teardown_test_db
  end

  def test_should_show_a_run_failed_once_its_slow_suite_s_process_has_exited
    FunCi::Persistence::PipelineRun.store_pid(@db, @run_id, exited_pid)

    assert_equal "failed", FunCi::Console::BoardData.new(@db).runs.first[:status]
  end

  def test_should_leave_a_run_running_while_its_slow_suite_s_process_lives
    FunCi::Persistence::PipelineRun.store_pid(@db, @run_id, Process.pid)

    assert_equal "running", FunCi::Console::BoardData.new(@db).runs.first[:status]
  end

  private

  def exited_pid
    pid = Process.spawn("true")
    Process.wait(pid)
    pid
  end
end
