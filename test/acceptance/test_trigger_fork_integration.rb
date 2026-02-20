# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/database"
require "fun_ci/pipeline_recorder"
require "fun_ci/pipeline_run"
require "fun_ci/background_wrapper"
require "tmpdir"

# Integration test for the real fork-based background path.
#
# This single test exercises the production fork cycle to catch
# regressions. All other acceptance tests use DI seams (no-op or
# sync launchers) for speed and determinism.
#
# Mirrors Trigger#default_background_launcher: the parent closes its
# DB, forks, and the child creates its own DbRecorder from db_path
# and pipeline_run_id. No shared state crosses the fork boundary.
#
# Uses Process.waitpid2 for deterministic child-process waiting
# (no polling, no Thread.pass, no sleep).

class TestTriggerForkIntegration < Minitest::Test
  def test_should_record_slow_suite_result_via_forked_process
    dir = Dir.mktmpdir("fun-ci-fork-test")
    db_path = File.join(dir, "test.sqlite3")
    db = FunCi::Database.connection(db_path)
    FunCi::Database.migrate!(db)
    recorder = FunCi::DbRecorder.new(db)

    # Set up a pipeline run with a running slow stage (as Trigger would
    # before calling the background launcher).
    recorder.create_run(commit_hash: "abc1234", branch: "main")
    job_id = recorder.start_stage("slow")
    pipeline_run_id = recorder.pipeline_run_id

    # A fake executor that succeeds (simulates slow.sh exiting 0)
    executor = -> { ["", FakeStatus.new(true, 0)] }

    # Fork like production: close parent DB, fork, child creates its
    # own DbRecorder from simple data. No shared objects cross the fork.
    recorder.close
    child_pid = fork do
      child_recorder = FunCi::DbRecorder.for_background(db_path, pipeline_run_id)
      FunCi::BackgroundWrapper.new(
        recorder: child_recorder, job_id: job_id, executor: executor
      ).run
      child_recorder.close
    end

    # Deterministic wait (no polling, no sleep)
    _, child_status = Process.waitpid2(child_pid)
    assert child_status.success?, "Forked child should exit successfully"

    # Reopen DB and verify the forked child recorded the result
    db = FunCi::Database.connection(db_path)

    runs = FunCi::PipelineRun.find_by_commit(db, "abc1234")
    assert_equal "completed", runs.first[:status],
      "Pipeline should be completed after forked slow suite finishes"

    jobs = db.execute(
      "SELECT stage, status FROM stage_jobs WHERE pipeline_run_id = ?",
      [runs.first[:id]]
    )
    slow_job = jobs.find { |j| j[0] == "slow" }
    assert_equal "completed", slow_job[1],
      "Slow stage should be completed via forked process"
  ensure
    db&.close
    FileUtils.remove_entry(dir) rescue nil
  end
end
