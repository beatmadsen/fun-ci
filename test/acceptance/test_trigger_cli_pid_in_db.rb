# frozen_string_literal: true

require_relative "trigger_cli_shared"

# Background process PIDs live in the pipeline_runs table, not in
# .fun-ci-pids/ files, and the stale pipeline canceller reads them from there.

class TestTriggerCliPidInDb < Minitest::Test
  def setup
    @client = TriggerCliClient.open(command_runner: INSTANT_SUCCESS_RUNNER)
    @stale_pid = nil
  end

  def teardown
    kill_stale_process if @stale_pid
    @client.close
  end

  def test_should_cancel_stale_pipeline_using_pid_from_database
    @client.trigger(commit_hash: "abc1234", branch: "main")
    old_run_id = @client.pipeline_runs_for(commit_hash: "abc1234").first[:id]
    mark_running_with_stale_process(old_run_id)
    @client.trigger(commit_hash: "def5678", branch: "main")
    old_run = FunCi::Persistence::PipelineRun.find(@client.db, old_run_id)
    assert_equal "cancelled", old_run[:status], "Old pipeline should be cancelled when superseded"
    assert_match(/cancell/i, @client.stdout, "Should inform user about cancelled stale pipeline")
  end

  def test_should_not_create_pid_files_on_filesystem
    @client.trigger(commit_hash: "abc1234", branch: "main")
    pid_dir = File.join(@client.project_dir, ".fun-ci-pids")
    refute Dir.exist?(pid_dir), "PID files should not be created — PIDs belong in the database"
  end

  private

  # A background process still alive for the run, with its PID stored in the
  # database rather than in a .fun-ci-pids/ file.
  def mark_running_with_stale_process(run_id)
    @stale_pid = Process.spawn("sleep 300")
    Process.detach(@stale_pid)
    @client.store_pid_for_run(run_id, @stale_pid)
    FunCi::Persistence::PipelineRun.update_status(@client.db, run_id, "running")
  end

  def kill_stale_process
    Process.kill("KILL", @stale_pid)
  rescue StandardError
    nil
  end
end
