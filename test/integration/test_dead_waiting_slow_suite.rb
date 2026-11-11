# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/console/board_data"
require "fun_ci/pipeline/run_canceller"

# A slow suite waiting its turn is a process that can die too, the machine
# restarting under it (acceptance-tests.md, AT-8.3, AT-9.19).
class TestDeadWaitingSlowSuite < Minitest::Test
  include DatabaseTestSetup
  include PipelineTestHelpers

  def setup
    setup_test_db
    run_id = create_pipeline_run("abc1234", "main", "running")
    @waiting = FunCi::Persistence::StageJob.create(@db, pipeline_run_id: run_id, stage: "slow")
    FunCi::Persistence::PipelineRun.store_pid(@db, run_id, 4242)
  end

  def teardown = teardown_test_db

  def test_should_record_failed_a_slow_stage_whose_process_died_while_it_waited_its_turn
    poll(->(_signal, _pid) { raise Errno::ESRCH })

    assert_equal "failed", FunCi::Persistence::StageJob.find(@db, @waiting)[:status]
  end

  def test_should_leave_waiting_a_slow_stage_whose_process_lives
    poll(->(_signal, _pid) {})

    assert_equal "scheduled", FunCi::Persistence::StageJob.find(@db, @waiting)[:status]
  end

  private

  def poll(killer)
    board = FunCi::Console::BoardData.new(@db, run_canceller: FunCi::Pipeline::RunCanceller.new(killer: killer))
    board.record_dead_slow_suites
  end
end
