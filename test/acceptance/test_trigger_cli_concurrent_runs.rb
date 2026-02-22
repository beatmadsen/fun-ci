# frozen_string_literal: true

require_relative "trigger_cli_shared"

# Acceptance tests for concurrent pipeline runs — stale pipeline cancellation.
# PIDs are stored in the database, not on the filesystem.

class TestTriggerCliConcurrentRuns < Minitest::Test
  def setup
    @client = TriggerCliClient.new(command_runner: INSTANT_SUCCESS_RUNNER)
    @stale_pid = nil
  end

  def teardown
    Process.kill("KILL", @stale_pid) rescue nil if @stale_pid
    @client.close
  end

  def test_should_cancel_stale_pipeline_when_same_branch_triggered_again
    # Given a pipeline has run and left a stale background process
    @client.trigger(commit_hash: "abc1234", branch: "main")
    old_run = @client.pipeline_runs_for(commit_hash: "abc1234").first
    # Simulate a stale slow suite process with PID in DB
    @stale_pid = Process.spawn("sleep 300")
    Process.detach(@stale_pid)
    @client.store_pid_for_run(old_run[:id], @stale_pid)
    FunCi::Persistence::PipelineRun.update_status(@client.db, old_run[:id], "running")
    # When the trigger CLI is invoked again for branch "main" with a new commit
    @client.trigger(commit_hash: "def5678", branch: "main")
    # Then stdout should mention cancelling the stale pipeline
    assert_match(/cancell/i, @client.stdout, "Should mention cancelling stale pipeline")
    # And exit code should be 0 (new pipeline started successfully)
    assert_equal 0, @client.exit_code, "New pipeline should succeed"
  end

  def test_should_mark_cancelled_pipeline_state_as_cancelled
    # Given a pipeline run exists for branch "main" with commit "abc1234"
    @client.trigger(commit_hash: "abc1234", branch: "main")
    old_run = @client.pipeline_runs_for(commit_hash: "abc1234").first
    # And a stale background process is still running for that pipeline
    @stale_pid = Process.spawn("sleep 300")
    Process.detach(@stale_pid)
    @client.store_pid_for_run(old_run[:id], @stale_pid)
    FunCi::Persistence::PipelineRun.update_status(@client.db, old_run[:id], "running")
    # When the trigger CLI is invoked again for the same branch
    @client.trigger(commit_hash: "def5678", branch: "main")
    # Then the old pipeline's state should be cancelled
    old_run = FunCi::Persistence::PipelineRun.find(@client.db, old_run[:id])
    assert_equal "cancelled", old_run[:status],
      "Old pipeline should be marked cancelled when superseded"
  end
end
