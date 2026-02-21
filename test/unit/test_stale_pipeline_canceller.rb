# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/stale_pipeline_canceller"
require "fun_ci/database"
require "fun_ci/pipeline_run"

class TestStalePipelineCancellerCancel < Minitest::Test
  include DatabaseTestSetup

  def setup
    setup_test_db
  end

  def teardown
    teardown_test_db
  end

  def test_should_mark_running_pipeline_as_cancelled_when_process_is_dead
    # Given a running pipeline with a PID stored in DB
    run_id = FunCi::PipelineRun.create(@db, commit_hash: "abc1234", branch: "main")
    FunCi::PipelineRun.update_status(@db, run_id, "running")
    FunCi::PipelineRun.store_pid(@db, run_id, 99999)
    stdout = StringIO.new
    # And a process_killer that reports the process is dead
    killed = []
    process_killer = ->(signal, pid) { killed << [signal, pid]; raise Errno::ESRCH }
    canceller = FunCi::StalePipelineCanceller.new(
      db: @db, branch: "main",
      stdout: stdout,
      process_killer: process_killer
    )
    # When cancel is called
    canceller.cancel(new_commit_hash: "def5678")
    # Then the old pipeline should be marked as cancelled
    old_run = FunCi::PipelineRun.find(@db, run_id)
    assert_equal "cancelled", old_run[:status],
      "Should mark dead pipeline as cancelled"
  end

  def test_should_kill_and_cancel_running_pipeline_when_process_is_alive
    # Given a running pipeline with a PID stored in DB
    run_id = FunCi::PipelineRun.create(@db, commit_hash: "abc1234", branch: "main")
    FunCi::PipelineRun.update_status(@db, run_id, "running")
    FunCi::PipelineRun.store_pid(@db, run_id, 12345)
    stdout = StringIO.new
    # And a process_killer that succeeds (process alive)
    killed = []
    process_killer = ->(signal, pid) { killed << [signal, pid] }
    canceller = FunCi::StalePipelineCanceller.new(
      db: @db, branch: "main",
      stdout: stdout,
      process_killer: process_killer
    )
    # When cancel is called
    canceller.cancel(new_commit_hash: "def5678")
    # Then it should send TERM then KILL signals
    assert_includes killed, ["TERM", 12345], "Should send TERM to stale process"
    assert_includes killed, ["KILL", 12345], "Should send KILL to stale process"
    # And the pipeline should be marked cancelled
    old_run = FunCi::PipelineRun.find(@db, run_id)
    assert_equal "cancelled", old_run[:status],
      "Should mark killed pipeline as cancelled"
  end

  def test_should_print_cancellation_message
    # Given a running pipeline with a PID
    run_id = FunCi::PipelineRun.create(@db, commit_hash: "abc1234", branch: "main")
    FunCi::PipelineRun.update_status(@db, run_id, "running")
    FunCi::PipelineRun.store_pid(@db, run_id, 12345)
    stdout = StringIO.new
    process_killer = ->(_signal, _pid) {}
    canceller = FunCi::StalePipelineCanceller.new(
      db: @db, branch: "main",
      stdout: stdout,
      process_killer: process_killer
    )
    # When cancel is called
    canceller.cancel(new_commit_hash: "def5678")
    # Then it should inform the user
    assert_match(/cancell.*abc1234/i, stdout.string,
      "Should mention cancelling the old commit")
    assert_match(/def5678/, stdout.string,
      "Should mention the new commit")
  end

  def test_should_do_nothing_when_no_running_pipeline_on_branch
    # Given no running pipeline on branch "main"
    stdout = StringIO.new
    killed = []
    process_killer = ->(signal, pid) { killed << [signal, pid] }
    canceller = FunCi::StalePipelineCanceller.new(
      db: @db, branch: "main",
      stdout: stdout,
      process_killer: process_killer
    )
    # When cancel is called
    canceller.cancel(new_commit_hash: "def5678")
    # Then no processes should be killed
    assert_empty killed, "Should not try to kill anything"
    # And no output
    assert_empty stdout.string, "Should not print anything"
  end
end
