# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/trigger_test_kit"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_recorder"
require "fun_ci/persistence/pipeline_run"

# The real fork-based background path. Every other trigger test injects a
# launcher; these fork like production and wait for the child with
# Process.waitpid, so nothing polls or sleeps.
class TestTriggerForkIntegration < Minitest::Test
  include FunCiTestProject
  include TriggerTestKit

  def setup
    @dir = Dir.mktmpdir("fun-ci-fork-test")
    @db_path = File.join(@dir, "test.sqlite3")
    FunCi::Persistence::Database.connection(@db_path).tap { |db| FunCi::Persistence::Database.migrate!(db) }.close
  end

  def teardown
    wait_for_child(@pid) if @pid
    FileUtils.rm_rf(@dir)
  end

  def test_the_forked_child_records_the_slow_suite_it_ran
    run_pipeline

    assert_equal("completed", with_db { |db| slow_status(db) })
  end

  def test_the_fast_suite_is_recorded_after_the_slow_suite_is_forked
    exit_code = run_pipeline

    assert_equal [0, "completed"], [exit_code, with_db { |db| stage_status(db, "fast") }]
  end

  def test_the_launcher_stores_the_child_pid
    run_pipeline

    refute_nil @pid
  end

  private

  def run_pipeline
    recorder = FunCi::Persistence::DbRecorder.new(FunCi::Persistence::Database.connection(@db_path))
    exit_code = in_project { |dir| run_and_close(forking_trigger(dir, recorder)) }
    @pid = with_db { |db| FunCi::Persistence::PipelineRun.find_by_commit(db, "abc1234").first[:pid] }
    exit_code
  end

  # A nil launcher puts the real forking one back.
  def forking_trigger(dir, recorder)
    build_trigger(dir, command_runner: scripted_runner, recorder: recorder, background_launcher: nil)
  end

  def run_and_close(trigger)
    trigger.run
  ensure
    trigger.close
  end

  def slow_status(db)
    wait_for_child(@pid)
    stage_status(db, "slow")
  end

  def stage_status(db, stage)
    run_id = FunCi::Persistence::PipelineRun.find_by_commit(db, "abc1234").first[:id]
    db.execute("SELECT status FROM stage_jobs WHERE pipeline_run_id = ? AND stage = ?", [run_id, stage]).dig(0, 0)
  end

  def with_db
    db = FunCi::Persistence::Database.connection(@db_path)
    yield db
  ensure
    db&.close
  end

  # Process.detach also waits on the child, so whichever waiter loses gets
  # ECHILD; either way the child has exited when this returns.
  def wait_for_child(pid)
    Process.waitpid(pid)
  rescue Errno::ECHILD
    nil
  end
end
