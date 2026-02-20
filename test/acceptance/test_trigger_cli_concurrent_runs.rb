# frozen_string_literal: true

require_relative "../test_helper"
require_relative "trigger_cli_client"

# Acceptance tests for concurrent pipeline runs — stale pipeline cancellation.

class TestTriggerCliConcurrentRuns < Minitest::Test
  def setup
    @client = TriggerCliClient.new
    @stale_pid = nil
  end

  def teardown
    Process.kill("KILL", @stale_pid) rescue nil if @stale_pid
    @client.close
  end

  def test_should_cancel_stale_pipeline_when_same_branch_triggered_again
    # Given a pipeline has run and left a stale background process
    @client.trigger(commit_hash: "abc1234", branch: "main")
    # Simulate a stale slow suite process (like the fork-based launcher would create)
    @stale_pid = Process.spawn("sleep 300")
    Process.detach(@stale_pid)
    pid_dir = File.join(@client.project_dir, ".fun-ci-pids")
    Dir.mkdir(pid_dir) unless Dir.exist?(pid_dir)
    File.write(File.join(pid_dir, "main.pid"), "#{@stale_pid}\nabc1234")
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
    old_runs = @client.pipeline_runs_for(commit_hash: "abc1234")
    old_run_id = old_runs.first[:id]
    # And a stale background process is still running for that pipeline
    @stale_pid = Process.spawn("sleep 300")
    Process.detach(@stale_pid)
    pid_dir = File.join(@client.project_dir, ".fun-ci-pids")
    Dir.mkdir(pid_dir) unless Dir.exist?(pid_dir)
    db_path = @client.db.filename("main")
    File.write(
      File.join(pid_dir, "main.pid"),
      "#{@stale_pid}\nabc1234\n#{db_path}\n#{old_run_id}"
    )
    # When the trigger CLI is invoked again for the same branch
    @client.trigger(commit_hash: "def5678", branch: "main")
    # Then the old pipeline's state should be cancelled
    old_run = FunCi::PipelineRun.find(@client.db, old_run_id)
    assert_equal "cancelled", old_run[:status],
      "Old pipeline should be marked cancelled when superseded"
  end
end
