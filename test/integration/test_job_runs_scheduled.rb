# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/persistence/job_runs"
require "fun_ci/persistence/active_jobs"
require "fun_ci/jobs/job"

# A claimed run that waits its turn to start (Jobs::Schedule, AT-13.28) is
# kept scheduled, from when it is to start, and is cancelled, found dead or
# begun as a running run is.
class TestJobRunsScheduled < Minitest::Test
  include DatabaseTestSetup

  NOW = Time.utc(2026, 10, 2, 12)
  LATER = NOW + 600
  SOAK = FunCi::Jobs::Job.new(name: "soak", cadence: "weekly", script: "/p/.fun-ci/weekly/soak.sh")

  def setup
    setup_test_db
    @runs = FunCi::Persistence::JobRuns.new(@db, "/p")
    @id = @runs.claim(SOAK, commit: { sha: "a" * 40, branch: "main" }, lock_file: "/soak.lock", now: NOW)
    @runs.wait_until(@id, LATER)
  end

  def teardown = teardown_test_db

  def test_should_record_a_run_that_waits_its_turn_scheduled
    assert_equal "scheduled", latest[:status]
  end

  def test_should_record_when_a_scheduled_run_is_to_start
    assert_equal LATER, Time.parse(latest[:started_at])
  end

  def test_should_record_a_scheduled_run_running_once_it_begins
    @runs.start_turn(@id, LATER + 3)

    assert_equal "running", latest[:status]
  end

  def test_should_record_when_a_scheduled_run_began
    @runs.start_turn(@id, LATER + 3)

    assert_equal LATER + 3, Time.parse(latest[:started_at])
  end

  def test_should_not_begin_a_run_cancelled_while_it_waited
    FunCi::Persistence::ActiveJobs.cancelled(@db, @id)

    assert_equal 0, @runs.start_turn(@id, LATER)
  end

  def test_should_leave_a_run_cancelled_while_it_waited_cancelled
    FunCi::Persistence::ActiveJobs.cancelled(@db, @id)
    @runs.start_turn(@id, LATER)

    assert_equal "cancelled", latest[:status]
  end

  def test_should_find_a_scheduled_run_to_cancel
    assert_equal [@id], FunCi::Persistence::ActiveJobs.with_id(@db, @id).map(&:id)
  end

  def test_should_list_a_scheduled_run_among_those_whose_process_may_have_died
    assert_equal [[@id, "/soak.lock"]], FunCi::Persistence::ActiveJobs.running(@db)
  end

  def test_should_record_failed_a_scheduled_run_whose_process_died
    @runs.died("soak")

    assert_equal "failed", latest[:status]
  end

  private

  def latest = @runs.latest("soak")
end
