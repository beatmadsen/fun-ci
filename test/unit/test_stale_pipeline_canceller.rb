# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/stale_pipeline_canceller"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"

class TestStalePipelineCancellerCancel < Minitest::Test
  include DatabaseTestSetup

  RUN = FunCi::Persistence::PipelineRun

  def setup
    setup_test_db
    @stdout = StringIO.new
    @killed = []
  end

  def teardown
    teardown_test_db
  end

  def test_should_mark_running_pipeline_as_cancelled_when_process_is_dead
    run_id = create_running_run(99_999)
    cancel_with(lambda { |signal, pid|
      @killed << [signal, pid]
      raise Errno::ESRCH
    })
    assert_equal "cancelled", RUN.find(@db, run_id)[:status],
                 "Should mark dead pipeline as cancelled"
  end

  def test_should_send_term_then_kill_to_live_stale_process
    create_running_run(12_345)
    cancel_with(recording_killer)
    assert_includes @killed, ["TERM", 12_345], "Should send TERM to stale process"
    assert_includes @killed, ["KILL", 12_345], "Should send KILL to stale process"
  end

  def test_should_mark_killed_pipeline_as_cancelled
    run_id = create_running_run(12_345)
    cancel_with(recording_killer)
    assert_equal "cancelled", RUN.find(@db, run_id)[:status],
                 "Should mark killed pipeline as cancelled"
  end

  def test_should_print_cancellation_message
    create_running_run(12_345)
    cancel_with(->(_signal, _pid) {})
    assert_match(/cancell.*abc1234/i, @stdout.string,
                 "Should mention cancelling the old commit")
    assert_match(/def5678/, @stdout.string,
                 "Should mention the new commit")
  end

  def test_should_not_kill_anything_when_no_running_pipeline_on_branch
    cancel_with(recording_killer)
    assert_empty @killed, "Should not try to kill anything"
  end

  def test_should_print_nothing_when_no_running_pipeline_on_branch
    cancel_with(recording_killer)
    assert_empty @stdout.string, "Should not print anything"
  end

  private

  def create_running_run(pid)
    run_id = RUN.create(@db, commit_hash: "abc1234", branch: "main")
    RUN.update_status(@db, run_id, "running")
    RUN.store_pid(@db, run_id, pid)
    run_id
  end

  def recording_killer
    ->(signal, pid) { @killed << [signal, pid] }
  end

  def cancel_with(process_killer)
    FunCi::Pipeline::StalePipelineCanceller.new(
      db: @db, branch: "main", stdout: @stdout, process_killer: process_killer
    ).cancel(new_commit_hash: "def5678")
  end
end
