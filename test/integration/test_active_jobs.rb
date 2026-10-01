# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/persistence/active_jobs"
require "fun_ci/persistence/job_runs"
require "fun_ci/persistence/job_recorder"
require "fun_ci/jobs/job"

# How a job's run whose process died, or that was cancelled, is recorded
# (acceptance-tests.md, AT-13.6, AT-13.15).
class TestActiveJobs < Minitest::Test
  include DatabaseTestSetup

  SOAK = FunCi::Jobs::Job.new(name: "soak", cadence: "weekly", script: "/project/.fun-ci/weekly/soak.sh")

  def setup
    setup_test_db
    @runs = FunCi::Persistence::JobRuns.new(@db, "/project")
    @id = @runs.claim(SOAK, commit: { sha: "abc1234", branch: "main" }, lock_file: "/soak.lock", now: Time.now)
  end

  def teardown = teardown_test_db

  def test_should_record_failed_a_run_whose_process_died
    FunCi::Persistence::ActiveJobs.died(@db, @id)

    assert_equal "failed", latest[:status]
  end

  def test_should_say_why_a_run_whose_process_died_has_no_result
    FunCi::Persistence::ActiveJobs.died(@db, @id)

    assert_includes latest[:evidence], "its process stopped before it said how the run ended"
  end

  # When it was found dead says nothing of how long it ran.
  def test_should_give_a_run_whose_process_died_no_end
    FunCi::Persistence::ActiveJobs.died(@db, @id)

    assert_nil latest[:completed_at]
  end

  def test_should_leave_a_run_that_ended_as_it_ended_when_found_dead
    FunCi::Persistence::JobRecorder.new(@db).end_stage(@id, "completed")
    FunCi::Persistence::ActiveJobs.died(@db, @id)

    assert_equal "completed", latest[:status]
  end

  def test_should_record_a_run_it_cancels_cancelled
    FunCi::Persistence::ActiveJobs.cancelled(@db, @id)

    assert_equal "cancelled", latest[:status]
  end

  def test_should_know_each_running_run_of_a_job
    assert_equal [@id], FunCi::Persistence::ActiveJobs.running_of(@db, "/project", "soak")
  end

  private

  def latest = @runs.latest("soak")
end
