# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/console/board_data"
require "fun_ci/pipeline/run_canceller"
require "delegate"

# AT-8.3: a slow suite whose forked process died without finishing is
# recorded failed, and its run with it, the next time the console polls.
class TestDeadSlowSuite < Minitest::Test
  include DatabaseTestSetup
  include PipelineTestHelpers

  SLOW_SUITE_PID = 4242
  DEAD = ->(_signal, _pid) { raise Errno::ESRCH }

  # The test's database, refusing every write with `error`: locked past its busy timeout, a full disk.
  class RefusingWrites < SimpleDelegator
    def initialize(db, error)
      super(db)
      @error = error
    end

    def execute(sql, *)
      raise @error, "refused" if sql.start_with?("UPDATE")

      super
    end
  end

  def setup
    setup_test_db
    @run_id = create_pipeline_run("abc1234", "main", "running")
    %w[lint build fast].each { |stage| create_stage_job(@run_id, stage, "running", "completed") }
    @slow = create_stage_job(@run_id, "slow", "running")
    FunCi::Persistence::PipelineRun.store_pid(@db, @run_id, SLOW_SUITE_PID)
  end

  def teardown
    teardown_test_db
  end

  def test_should_record_the_slow_stage_failed_when_its_process_is_gone
    poll(answering: Errno::ESRCH)

    assert_equal "failed", FunCi::Persistence::StageJob.find(@db, @slow)[:status]
  end

  def test_should_show_the_run_failed_when_its_slow_suite_died
    assert_equal "failed", poll(answering: Errno::ESRCH).first[:status]
  end

  def test_should_keep_the_result_a_slow_suite_recorded_just_before_it_exited
    # Given a slow suite that records its pass, then exits, while the console checks on it
    finishing = lambda do |_signal, _pid|
      FunCi::Persistence::StageJob.update_status(@db, @slow, "completed")
      raise Errno::ESRCH
    end

    # When the console polls
    poll_with(finishing)

    # Then the pass stands
    assert_equal "completed", FunCi::Persistence::StageJob.find(@db, @slow)[:status],
                 "a result recorded before the write must not be overwritten"
  end

  def test_should_still_show_the_runs_when_the_database_stays_busy
    assert_equal ["running"], statuses_polled_over(SQLite3::BusyException), "a busy database must not break the poll"
  end

  def test_should_still_show_the_runs_when_the_database_cannot_be_written
    assert_equal ["running"], statuses_polled_over(SQLite3::FullException), "a full disk must not break the poll"
  end

  def test_should_leave_the_slow_stage_running_while_its_process_lives
    poll(answering: nil)

    assert_equal "running", FunCi::Persistence::StageJob.find(@db, @slow)[:status]
  end

  def test_should_leave_a_slow_stage_running_before_its_process_is_recorded
    FunCi::Persistence::PipelineRun.store_pid(@db, @run_id, nil)

    poll(answering: Errno::ESRCH)

    assert_equal "running", FunCi::Persistence::StageJob.find(@db, @slow)[:status]
  end

  def test_should_count_a_process_it_may_not_signal_as_alive
    poll(answering: Errno::EPERM)

    assert_equal "running", FunCi::Persistence::StageJob.find(@db, @slow)[:status]
  end

  def test_should_ask_only_whether_the_process_exists
    signals = []
    poll_with(->(*args) { signals << args })

    assert_equal [[0, SLOW_SUITE_PID]], signals
  end

  private

  # The console's runs, where probing the slow suite's process raises `error` (nil: it exists).
  def poll(answering:)
    poll_with(->(_signal, _pid) { answering && raise(answering) })
  end

  # The runs a console poll shows, recording dead slow suites first as the console does.
  def poll_with(killer, db: @db)
    board = FunCi::Console::BoardData.new(db, run_canceller: canceller(killer))
    board.record_dead_slow_suites
    board.runs
  end

  # The runs' statuses a poll shows over a database refusing writes with `error`, a slow suite having died.
  def statuses_polled_over(error)
    poll_with(DEAD, db: RefusingWrites.new(@db, error)).map { |run| run[:status] }
  end

  def canceller(killer) = FunCi::Pipeline::RunCanceller.new(killer: killer)
end
