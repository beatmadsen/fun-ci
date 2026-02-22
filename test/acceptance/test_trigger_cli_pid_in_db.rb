# frozen_string_literal: true

require_relative "trigger_cli_shared"

# Acceptance test: PID storage in database instead of filesystem.
# Part 1 of "TUI cancel kills background process" feature.
#
# After this feature, background process PIDs are stored in the
# pipeline_runs table, not in .fun-ci-pids/ files. The stale
# pipeline canceller reads PIDs from the DB.

class TestTriggerCliPidInDb < Minitest::Test
  def setup
    @client = TriggerCliClient.new(command_runner: INSTANT_SUCCESS_RUNNER)
    @stale_pid = nil
  end

  def teardown
    Process.kill("KILL", @stale_pid) rescue nil if @stale_pid
    @client.close
  end

  def test_should_cancel_stale_pipeline_using_pid_from_database
    # Given a pipeline has run for branch "main"
    @client.trigger(commit_hash: "abc1234", branch: "main")
    old_run = @client.pipeline_runs_for(commit_hash: "abc1234").first

    # And a stale background process is still running for that pipeline
    @stale_pid = Process.spawn("sleep 300")
    Process.detach(@stale_pid)

    # And its PID is stored in the database (the new way)
    @client.store_pid_for_run(old_run[:id], @stale_pid)
    FunCi::Persistence::PipelineRun.update_status(@client.db, old_run[:id], "running")

    # When the trigger CLI is invoked again for the same branch
    @client.trigger(commit_hash: "def5678", branch: "main")

    # Then the old pipeline should be marked as cancelled
    old_run = FunCi::Persistence::PipelineRun.find(@client.db, old_run[:id])
    assert_equal "cancelled", old_run[:status],
      "Old pipeline should be cancelled when superseded"

    # And stdout should mention cancellation
    assert_match(/cancell/i, @client.stdout,
      "Should inform user about cancelled stale pipeline")
  end

  def test_should_not_create_pid_files_on_filesystem
    # Given a trigger run completes
    @client.trigger(commit_hash: "abc1234", branch: "main")

    # Then no .fun-ci-pids/ directory should exist
    pid_dir = File.join(@client.project_dir, ".fun-ci-pids")
    refute Dir.exist?(pid_dir),
      "PID files should not be created — PIDs belong in the database"
  end
end
