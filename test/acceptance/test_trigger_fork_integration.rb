# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/trigger"
require "fun_ci/database"
require "fun_ci/pipeline_recorder"
require "fun_ci/pipeline_run"
require "fun_ci/background_wrapper"
require "tmpdir"

# Integration tests for the real fork-based background path.
#
# These tests exercise the production fork cycle to catch regressions.
# All other acceptance tests use DI seams (no-op or sync launchers)
# for speed and determinism.
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

    # Fork like production: close parent DB before fork to prevent
    # inherited writable connections, then child creates its own fresh
    # DbRecorder. Only simple data (db_path, pipeline_run_id, job_id)
    # crosses the fork boundary.
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

    # Reopen DB to verify the forked child recorded the result
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

# Acceptance test: full Trigger#run with the real default_background_launcher.
# Verifies that the fast suite can still record its result after spawning
# the slow suite in the background.
class TestTriggerRunWithDefaultBackgroundLauncher < Minitest::Test
  include FunCiTestProject

  def test_should_record_fast_suite_after_spawning_slow_suite
    # Given a project with all scripts and a real DB
    project_dir = Dir.mktmpdir("fun-ci-project")
    make_project_with_scripts(project_dir)
    db_dir = Dir.mktmpdir("fun-ci-db")
    db_path = File.join(db_dir, "test.sqlite3")
    db = FunCi::Database.connection(db_path)
    FunCi::Database.migrate!(db)
    recorder = FunCi::DbRecorder.new(db)

    # Injected command_runner so scripts don't actually execute
    runner = ->(_cmd) { ["", FakeStatus.new(true, 0)] }

    # When Trigger#run uses the real default_background_launcher (no DI override)
    trigger = FunCi::Trigger.new(
      project_root: project_dir,
      commit_hash: "abc1234",
      branch: "main",
      recorder: recorder,
      command_runner: runner,
      commit_validator: ->(_) { true }
    )
    exit_code = trigger.run

    # Then the trigger should succeed
    assert_equal 0, exit_code,
      "Trigger should succeed when all stages pass"

    # And the fast suite should be recorded in the database
    # (reopen connection — production code closed the original for fork safety)
    verify_db = FunCi::Database.connection(db_path)
    runs = FunCi::PipelineRun.find_by_commit(verify_db, "abc1234")
    refute_empty runs, "Should have a pipeline run"
    jobs = verify_db.execute(
      "SELECT stage, status FROM stage_jobs WHERE pipeline_run_id = ?",
      [runs.first[:id]]
    )
    fast_job = jobs.find { |j| j[0] == "fast" }
    refute_nil fast_job, "Fast stage should be recorded"
    assert_equal "completed", fast_job[1],
      "Fast stage should be completed after slow suite is spawned"
  ensure
    verify_db&.close rescue nil
    FileUtils.remove_entry(db_dir) rescue nil
    FileUtils.remove_entry(project_dir) rescue nil
  end
end
