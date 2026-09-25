# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/trigger_test_kit"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_recorder"
require "fun_ci/persistence/pipeline_run"

# The real fork-based background path. Every other trigger test injects a
# launcher; these fork like production and wait for the child with
# Process.waitpid, so nothing polls or sleeps.
class TestTriggerForkIntegration < Minitest::Test
  # A slot held through a real flock, as WorktreePool hands them out.
  LockedWorkspace = Struct.new(:path, :lock_path) do
    def acquire(_sha)
      lock = File.new(lock_path, File::RDWR | File::CREAT)
      lock.flock(File::LOCK_EX)
      FunCi::Pipeline::Slot.new(path, lock)
    end
  end

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

  def test_the_pipeline_passes_with_the_real_forking_launcher
    assert_equal 0, run_pipeline
  end

  def test_the_fast_suite_is_recorded_after_the_slow_suite_is_forked
    run_pipeline

    assert_equal("completed", with_db { |db| stage_status(db, "fast") })
  end

  def test_the_slot_is_free_once_the_forked_slow_suite_has_finished
    lock = File.join(@dir, "slot.lock")
    run_pipeline(lock: lock)
    wait_for_child(@pid)

    assert(File.open(lock) { |file| file.flock(File::LOCK_EX | File::LOCK_NB) })
  end

  def test_the_launcher_stores_the_child_pid
    run_pipeline

    refute_nil @pid
  end

  # The slow suite waits on a pipe, so the child is still running when the
  # waiter is looked for, and exits only when the test lets it.
  def test_the_launcher_reaps_its_child_when_the_slow_suite_ends
    gate, release = IO.pipe
    run_pipeline(runner: ->(cmd) { cmd.include?("slow.sh") ? wait_for(gate, release) : PASS })
    waiter = Thread.list.grep(Process::Waiter).find { |thread| thread.pid == @pid }
    release.close

    assert_predicate waiter.value, :success?
  end

  private

  def run_pipeline(runner: scripted_runner, lock: nil)
    recorder = FunCi::Persistence::DbRecorder.new(FunCi::Persistence::Database.connection(@db_path))
    exit_code = in_project { |dir| run_and_close(forking_trigger(dir, recorder, runner, lock)) }
    @pid = with_db { |db| FunCi::Persistence::PipelineRun.find_by_commit(db, "abc1234").first[:pid] }
    exit_code
  end

  # Runs in the forked child, which holds its own copy of the write end and
  # has to close it before reading can end.
  def wait_for(gate, release)
    release.close
    [gate.read, FakeStatus.new(true, 0)]
  end

  # Seams left to their defaults fork the slow suite for real.
  def forking_trigger(dir, recorder, runner, lock)
    workspace = lock ? LockedWorkspace.new(dir, lock) : FunCi::Pipeline::InPlace.new(dir)
    seams = FunCi::Pipeline::Seams.new(command_runner: runner, recorder: recorder, commit_validator: ->(_) { true },
                                       workspace: workspace)
    FunCi::Pipeline::Trigger.new(project: dir, commit: FunCi::Pipeline::Commit.new(sha: "abc1234", branch: "main"),
                                 io: quiet_io, seams: seams)
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
