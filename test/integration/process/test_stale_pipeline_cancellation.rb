# frozen_string_literal: true

require_relative "../../acceptance/trigger_cli_shared"

# A pipeline superseded on its branch is cancelled through the pid stored in
# the database. The stale pipeline is a real process, so this lives here.
class TestStalePipelineCancellation < Minitest::Test
  RUN = FunCi::Persistence::PipelineRun

  def setup
    @client = TriggerCliClient.open(command_runner: INSTANT_SUCCESS_RUNNER)
  end

  def teardown
    stop_stale_process if @stale_pid
    @client.close
  end

  def test_should_mark_the_superseded_pipeline_cancelled
    old_run_id = supersede_stale_pipeline

    assert_equal "cancelled", RUN.find(@client.db, old_run_id)[:status]
  end

  def test_should_tell_the_user_the_stale_pipeline_was_cancelled
    supersede_stale_pipeline

    assert_match(/Cancelled stale pipeline for abc1234/, @client.stdout)
  end

  def test_should_let_the_new_pipeline_pass
    supersede_stale_pipeline

    assert_equal 0, @client.exit_code
  end

  private

  def supersede_stale_pipeline
    @client.trigger(commit_hash: "abc1234", branch: "main")
    old_run_id = @client.pipeline_runs_for(commit_hash: "abc1234").first[:id]
    leave_stale_process_for(old_run_id)
    @client.trigger(commit_hash: "def5678", branch: "main")
    old_run_id
  end

  # The canceller has usually killed it already, and the detach thread may
  # have reaped it; either way it is gone once the waiter finishes.
  def stop_stale_process
    Process.kill("KILL", @stale_pid)
  rescue Errno::ESRCH
    nil
  ensure
    @waiter.join
  end

  def leave_stale_process_for(run_id)
    @stale_pid = Process.spawn("sleep 300")
    @waiter = Process.detach(@stale_pid)
    @client.store_pid_for_run(run_id, @stale_pid)
    RUN.update_status(@client.db, run_id, "running")
  end
end
