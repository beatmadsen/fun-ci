# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/board_data"
require "fun_ci/persistence/database"

# AT-1.12: cancelling from the console stops the run's processes, through the
# same RunCanceller a newer commit uses, and records it cancelled.
class TestBoardDataCancel < Minitest::Test
  include DatabaseTestSetup

  RUN = FunCi::Persistence::PipelineRun

  def setup
    setup_test_db
    @signals = []
  end

  def teardown = teardown_test_db

  def test_should_stop_the_processes_of_the_run_it_cancels
    cancel(running_run)

    assert_equal [["KILL", 100]], @signals
  end

  def test_should_record_the_run_it_cancels_as_cancelled
    run_id = running_run
    cancel(run_id)

    assert_equal "cancelled", RUN.find(@db, run_id)[:status]
  end

  def test_should_leave_a_finished_run_alone
    run_id = running_run
    RUN.update_status(@db, run_id, "completed")
    cancel(run_id)

    assert_empty @signals
  end

  private

  def running_run
    RUN.create(@db, commit_hash: "abc1234", branch: "main").tap do |id|
      RUN.update_status(@db, id, "running")
      RUN.store_trigger_pid(@db, id, 100)
    end
  end

  def cancel(run_id)
    canceller = FunCi::Pipeline::RunCanceller.new(killer: ->(signal, pid) { @signals << [signal, pid] })
    FunCi::Tui::BoardData.new(@db, run_canceller: canceller).cancel_run(run_id)
  end
end
