# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/console/board_data"
require "fun_ci/pipeline/run_canceller"

# AT-8.3: a slow suite whose forked process died without finishing is
# recorded failed, and its run with it, the next time the console polls.
class TestDeadSlowSuite < Minitest::Test
  include DatabaseTestSetup
  include PipelineTestHelpers

  SLOW_SUITE_PID = 4242

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
    FunCi::Console::BoardData.new(@db, run_canceller: canceller(finishing)).runs

    # Then the pass stands
    assert_equal "completed", FunCi::Persistence::StageJob.find(@db, @slow)[:status],
                 "a result recorded before the write must not be overwritten"
  end

  def test_should_leave_the_slow_stage_running_while_its_process_lives
    poll(answering: nil)

    assert_equal "running", FunCi::Persistence::StageJob.find(@db, @slow)[:status]
  end

  def test_should_count_a_process_it_may_not_signal_as_alive
    poll(answering: Errno::EPERM)

    assert_equal "running", FunCi::Persistence::StageJob.find(@db, @slow)[:status]
  end

  def test_should_ask_only_whether_the_process_exists
    signals = []
    FunCi::Console::BoardData.new(@db, run_canceller: canceller(->(*args) { signals << args })).runs

    assert_equal [[0, SLOW_SUITE_PID]], signals
  end

  private

  # The console's runs, where probing the slow suite's process raises `error` (nil: it exists).
  def poll(answering:)
    probe = ->(_signal, _pid) { answering && raise(answering) }
    FunCi::Console::BoardData.new(@db, run_canceller: canceller(probe)).runs
  end

  def canceller(killer) = FunCi::Pipeline::RunCanceller.new(killer: killer)
end
