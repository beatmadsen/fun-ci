# frozen_string_literal: true

require_relative "../test_helper"
require_relative "trigger_cli_client"

# Acceptance tests for concurrent pipeline runs and database resilience.
#
# Covers: stale pipeline cancellation on re-trigger,
# database locking retry, persistent lock error, unwritable DB.

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
    skip "Pending: requires database integration for state tracking"
    # Given a pipeline is running for branch "main"
    # When a new trigger cancels the old pipeline
    # Then the old pipeline's state in the database should be Cancelled
  end
end

class TestTriggerCliDatabaseResilience < Minitest::Test
  def setup
    @client = TriggerCliClient.new
  end

  def teardown
    @client.close
  end

  def test_should_retry_when_database_is_locked
    skip "Pending: scaffold only -- no implementation yet"
    # Given the SQLite database is locked by another process
    # When the trigger CLI attempts to write a result
    # Then it should retry up to 3 times with brief backoff
    # And eventually succeed when the lock is released
  end

  def test_should_report_error_when_database_is_persistently_locked
    skip "Pending: scaffold only -- no implementation yet"
    # Given the SQLite database is locked and stays locked
    # When the trigger CLI exhausts all 3 retries
    # Then exit code should be non-zero
    # And stderr should mention the database being busy
    # And stderr should say "re-trigger to update status"
  end

  def test_should_report_error_when_database_is_unwritable
    skip "Pending: scaffold only -- no implementation yet"
    # Given the disk is full or the database path is unwritable
    # When the trigger CLI attempts to write
    # Then exit code should be non-zero
    # And stderr should mention the database path
  end
end
