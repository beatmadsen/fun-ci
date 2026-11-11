# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/persistence/job_visibility"
require "fun_ci/persistence/job_runs"
require "fun_ci/persistence/job_recorder"
require "fun_ci/persistence/active_jobs"
require "fun_ci/jobs/job"

# When a snooze is over as a job's runs wait their turn, begin and are
# cancelled (design.md, The console; acceptance-tests.md, AT-13.29).
class TestJobVisibilityTurns < Minitest::Test
  include DatabaseTestSetup

  SNOOZED = Time.utc(2026, 10, 2, 12)
  DAY = 86_400
  SOAK = FunCi::Jobs::Job.new(name: "soak", cadence: "daily", script: "/p/.fun-ci/daily/soak.sh")
  COMMIT = { sha: "a" * 40, branch: "main" }.freeze

  def setup
    setup_test_db
    @visibility = FunCi::Persistence::JobVisibility.new(@db)
    @runs = FunCi::Persistence::JobRuns.new(@db, "/p")
  end

  def teardown = teardown_test_db

  def test_should_keep_a_snoozed_job_out_of_view_while_its_next_run_waits_its_turn
    snooze
    @runs.wait_until(start_a_run(SNOOZED + 60), SNOOZED + 600)

    assert_equal({ "soak" => "snoozed" }, @visibility.hidden("/p"))
  end

  def test_should_bring_a_snoozed_job_back_when_the_run_that_waited_begins
    snooze
    id = start_a_run(SNOOZED + 60)
    @runs.wait_until(id, SNOOZED + 600)
    @runs.start_turn(id, SNOOZED + 600)

    assert_empty @visibility.hidden("/p")
  end

  # A run cancelled before its turn never ran (design.md, Daily and weekly jobs).
  def test_should_keep_a_snoozed_job_out_of_view_when_its_next_run_was_cancelled_while_it_waited
    snooze
    id = start_a_run(SNOOZED + 60)
    @runs.wait_until(id, SNOOZED + 600)
    FunCi::Persistence::ActiveJobs.cancelled(@db, id)

    assert_equal({ "soak" => "snoozed" }, @visibility.hidden("/p"))
  end

  # It began, so the snooze is over, whatever became of that run.
  def test_should_leave_a_job_in_view_once_the_run_that_brought_it_back_was_cancelled
    snooze
    FunCi::Persistence::ActiveJobs.cancelled(@db, start_a_run(SNOOZED + 60))

    assert_empty @visibility.hidden("/p")
  end

  # fun-ci 2.4.0 and earlier kept no time a run began, only when it started.
  def test_should_bring_a_snoozed_job_back_for_a_run_an_earlier_version_kept
    snooze
    @db.execute("UPDATE job_runs SET began_at = NULL WHERE id = ?", [start_a_run(SNOOZED + 60)])

    assert_empty @visibility.hidden("/p")
  end

  # It ran again, so the snooze is over, whatever its runs after that do.
  def test_should_leave_a_job_in_view_while_a_later_run_waits_once_it_ran_after_the_snooze
    snooze
    FunCi::Persistence::JobRecorder.new(@db).end_stage(start_a_run(SNOOZED + 60), "failed")
    @runs.wait_until(start_a_run(SNOOZED + 60 + DAY), SNOOZED + (2 * DAY))

    assert_empty @visibility.hidden("/p")
  end

  private

  def snooze = @visibility.hide("/p", "soak", "snoozed", at: SNOOZED)

  # A run of soak running from `at`; its id.
  def start_a_run(at) = @runs.claim(SOAK, commit: COMMIT, lock_file: "/soak.lock", now: at)
end
