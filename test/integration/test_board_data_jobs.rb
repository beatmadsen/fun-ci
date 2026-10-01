# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/console/board_data"
require "fun_ci/persistence/database"
require "fun_ci/persistence/job_runs"
require "fun_ci/persistence/job_recorder"
require "fun_ci/jobs/job"
require "delegate"

# What the console does to a job's run: cancel it from the cursor, stopping
# its processes as a run's are stopped, and record failed one whose process
# died, when it polls (acceptance-tests.md, AT-13.6, AT-13.15).
class TestBoardDataJobs < Minitest::Test
  include DatabaseTestSetup

  # The test's database, refusing every write with SQLite3::BusyException, as one locked past its busy timeout does.
  class Busy < SimpleDelegator
    def execute(sql, *)
      raise SQLite3::BusyException, "refused" if sql.start_with?("UPDATE")

      super
    end
  end

  SOAK = FunCi::Jobs::Job.new(name: "soak", cadence: "weekly", script: "/project/.fun-ci/weekly/soak.sh")

  def setup
    setup_test_db
    @signals = []
    @runs = FunCi::Persistence::JobRuns.new(@db, "/project")
    @id = @runs.claim(SOAK, commit: { sha: "abc1234", branch: "main" }, lock_file: "/soak.lock", now: Time.now)
    FunCi::Persistence::JobRecorder.new(@db).tap { |recorder| recorder.started_by(@id, 100) }
                                   .stage_process(@id, 200)
  end

  def teardown = teardown_test_db

  def test_should_stop_the_job_s_process_and_its_script_s_group_when_it_cancels_the_job
    board(lock_held: true).cancel_job(@id)

    assert_equal [["KILL", 100], ["KILL", -200]], @signals
  end

  # The runner records its script's group while the cancel reads, so the cancel looks again once the runner is dead.
  def test_should_stop_a_script_s_group_recorded_after_the_cancel_first_looked
    recording_late = lambda do |signal, pid|
      FunCi::Persistence::JobRecorder.new(@db).stage_process(@id, 300) if pid == 100
      @signals << [signal, pid]
    end
    board(lock_held: true, killer: recording_late).cancel_job(@id)

    assert_includes @signals, ["KILL", -300]
  end

  def test_should_record_a_job_it_cancels_cancelled
    board(lock_held: true).cancel_job(@id)

    assert_equal "cancelled", status
  end

  def test_should_leave_a_finished_job_alone_when_asked_to_cancel_it
    FunCi::Persistence::JobRecorder.new(@db).end_stage(@id, "completed")
    board(lock_held: true).cancel_job(@id)

    assert_empty @signals
  end

  def test_should_record_failed_a_running_job_whose_lock_nobody_holds
    board(lock_held: false).record_dead_jobs

    assert_equal "failed", status
  end

  def test_should_say_why_a_job_whose_process_died_has_no_result
    board(lock_held: false).record_dead_jobs

    assert_includes @runs.latest("soak")[:evidence], "its process stopped before it said how the run ended"
  end

  # When it was found dead says nothing of how long it ran.
  def test_should_give_a_job_whose_process_died_no_end
    board(lock_held: false).record_dead_jobs

    assert_nil @runs.latest("soak")[:completed_at]
  end

  def test_should_leave_running_a_job_whose_lock_is_held
    board(lock_held: true).record_dead_jobs

    assert_equal "running", status
  end

  def test_should_leave_a_dead_job_to_the_next_poll_while_the_database_is_busy
    board(lock_held: false, db: Busy.new(@db)).record_dead_jobs

    assert_equal "running", status
  end

  def test_should_list_the_jobs_of_the_projects_on_the_board
    project = project_with_a_job("soak.sh")
    FunCi::Persistence::PipelineRun.create(@db, commit_hash: "abc1234", branch: "main", project_path: project)
    board = FunCi::Console::BoardData.new(@db, clock: -> { Time.now })

    assert_equal(["soak"], board.jobs(board.runs).map(&:name))
  end

  private

  def project_with_a_job(script)
    project = File.join(@dir, "project")
    path = File.join(project, ".fun-ci", "weekly", script)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "#!/bin/sh\n")
    File.chmod(0o755, path)
    project
  end

  def status = @runs.latest("soak")[:status]

  def board(lock_held:, db: @db, killer: ->(signal, pid) { @signals << [signal, pid] })
    canceller = FunCi::Pipeline::RunCanceller.new(killer: killer, slot_held: ->(_path) { lock_held })
    FunCi::Console::BoardData.new(db, run_canceller: canceller)
  end
end
