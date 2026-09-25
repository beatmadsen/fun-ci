# frozen_string_literal: true

require_relative "trigger_cli_shared"

# Acceptance tests for concurrent pipeline runs — stale pipeline cancellation.
# PIDs are stored in the database, not on the filesystem.

class TestTriggerCliConcurrentRuns < Minitest::Test
  RUN = FunCi::Persistence::PipelineRun

  def setup
    @client = TriggerCliClient.open(command_runner: INSTANT_SUCCESS_RUNNER)
    @stale_pid = nil
  end

  def teardown
    kill_stale_process
    @client.close
  end

  def test_should_cancel_stale_pipeline_when_same_branch_triggered_again
    supersede_stale_pipeline
    assert_match(/cancell/i, @client.stdout, "Should mention cancelling stale pipeline")
    assert_equal 0, @client.exit_code, "New pipeline should succeed"
  end

  def test_should_mark_cancelled_pipeline_state_as_cancelled
    old_run_id = supersede_stale_pipeline
    assert_equal "cancelled", RUN.find(@client.db, old_run_id)[:status],
                 "Old pipeline should be marked cancelled when superseded"
  end

  private

  def supersede_stale_pipeline
    @client.trigger(commit_hash: "abc1234", branch: "main")
    old_run_id = @client.pipeline_runs_for(commit_hash: "abc1234").first[:id]
    leave_stale_process_for(old_run_id)
    @client.trigger(commit_hash: "def5678", branch: "main")
    old_run_id
  end

  def leave_stale_process_for(run_id)
    @stale_pid = Process.spawn("sleep 300")
    Process.detach(@stale_pid)
    @client.store_pid_for_run(run_id, @stale_pid)
    RUN.update_status(@client.db, run_id, "running")
  end

  def kill_stale_process
    Process.kill("KILL", @stale_pid) if @stale_pid
  rescue StandardError
    nil
  end
end
