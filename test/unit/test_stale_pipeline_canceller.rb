# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/stale_pipeline_canceller"
require "fun_ci/database"
require "fun_ci/pipeline_run"

class TestStalePipelineCancellerDbUpdate < Minitest::Test
  include DatabaseTestSetup

  def setup
    setup_test_db
    @project_dir = Dir.mktmpdir("fun-ci-test")
  end

  def teardown
    teardown_test_db
    FileUtils.remove_entry(@project_dir) rescue nil
  end

  def test_should_mark_old_pipeline_as_cancelled_when_pid_file_has_db_info
    # Given a pipeline run exists in the database in "running" state
    run_id = FunCi::PipelineRun.create(@db, commit_hash: "abc1234", branch: "main")
    FunCi::PipelineRun.update_status(@db, run_id, "running")
    db_path = @db.filename("main")
    # And a PID file exists with a dead process but includes db_path and run_id
    dead_pid = 2_000_000_000
    pid_dir = File.join(@project_dir, ".fun-ci-pids")
    Dir.mkdir(pid_dir)
    File.write(
      File.join(pid_dir, "main.pid"),
      "#{dead_pid}\nabc1234\n#{db_path}\n#{run_id}"
    )
    stdout = StringIO.new
    canceller = FunCi::StalePipelineCanceller.new(
      project_root: @project_dir, branch: "main",
      commit_hash: "def5678", stdout: stdout
    )
    # When cancel is called
    canceller.cancel
    # Then the old pipeline run should be marked as cancelled
    old_run = FunCi::PipelineRun.find(@db, run_id)
    assert_equal "cancelled", old_run[:status],
      "Should mark old pipeline as cancelled via DB"
  end

  def test_should_not_fail_when_pid_file_has_no_db_info
    # Given a PID file in the old 2-line format (no db_path or run_id)
    dead_pid = 2_000_000_000
    pid_dir = File.join(@project_dir, ".fun-ci-pids")
    Dir.mkdir(pid_dir)
    File.write(
      File.join(pid_dir, "main.pid"),
      "#{dead_pid}\nabc1234"
    )
    stdout = StringIO.new
    canceller = FunCi::StalePipelineCanceller.new(
      project_root: @project_dir, branch: "main",
      commit_hash: "def5678", stdout: stdout
    )
    # When cancel is called
    canceller.cancel
    # Then it should not raise (graceful backward compatibility)
    pid_file = File.join(pid_dir, "main.pid")
    refute File.exist?(pid_file), "Should still clean up old-format PID file"
  end
end
