# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/persistence/job_visibility"
require "fun_ci/persistence/job_runs"
require "fun_ci/persistence/job_recorder"
require "fun_ci/persistence/active_jobs"
require "fun_ci/jobs/job"

# Which jobs the console keeps out of view (design.md, The console): an
# ignored job until it is shown again, a snoozed one until a run of it starts
# after the snooze (acceptance-tests.md, AT-13.29, AT-13.30).
class TestJobVisibility < Minitest::Test
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

  def test_should_keep_an_ignored_job_out_of_view
    @visibility.hide("/p", "soak", "ignored", at: SNOOZED)

    assert_equal({ "soak" => "ignored" }, @visibility.hidden("/p"))
  end

  def test_should_keep_an_ignored_job_out_of_view_when_it_runs_again
    @visibility.hide("/p", "soak", "ignored", at: SNOOZED)
    start_a_run(SNOOZED + 60)

    assert_equal({ "soak" => "ignored" }, @visibility.hidden("/p"))
  end

  def test_should_keep_a_snoozed_job_out_of_view_while_it_has_not_run_since
    start_a_run(SNOOZED - DAY)
    snooze

    assert_equal({ "soak" => "snoozed" }, @visibility.hidden("/p"))
  end

  def test_should_bring_a_snoozed_job_back_when_a_run_of_it_starts
    snooze
    start_a_run(SNOOZED + 60)

    assert_empty @visibility.hidden("/p")
  end

  def test_should_leave_a_job_in_view_once_the_run_that_brought_it_back_passed
    snooze
    FunCi::Persistence::JobRecorder.new(@db).end_stage(start_a_run(SNOOZED + 60), "completed")

    assert_empty @visibility.hidden("/p")
  end

  def test_should_leave_a_job_in_view_once_the_run_that_brought_it_back_ran_out_of_time
    snooze
    FunCi::Persistence::JobRecorder.new(@db).end_stage(start_a_run(SNOOZED + 60), "timed_out")

    assert_empty @visibility.hidden("/p")
  end

  # Until it runs again: the run going when it was snoozed is not that.
  def test_should_keep_a_job_snoozed_while_it_ran_out_of_view_once_that_run_ends
    FunCi::Persistence::JobRecorder.new(@db).end_stage(start_a_run(SNOOZED - 60), "failed")
    snooze

    assert_equal({ "soak" => "snoozed" }, @visibility.hidden("/p"))
  end

  def test_should_show_a_hidden_job_again_when_told_to
    @visibility.hide("/p", "soak", "ignored", at: SNOOZED)
    @visibility.show("/p", "soak")

    assert_empty @visibility.hidden("/p")
  end

  def test_should_keep_the_latest_of_two_ways_a_job_was_hidden
    snooze
    @visibility.hide("/p", "soak", "ignored", at: SNOOZED + 1)

    assert_equal({ "soak" => "ignored" }, @visibility.hidden("/p"))
  end

  def test_should_hide_a_job_in_its_own_project_alone
    @visibility.hide("/other", "soak", "ignored", at: SNOOZED)

    assert_empty @visibility.hidden("/p")
  end

  def test_should_not_bring_a_snoozed_job_back_for_another_project_s_run_of_its_name
    snooze
    FunCi::Persistence::JobRuns.new(@db, "/other").claim(SOAK, commit: COMMIT, lock_file: "/l", now: SNOOZED + 60)

    assert_equal({ "soak" => "snoozed" }, @visibility.hidden("/p"))
  end

  private

  def snooze = @visibility.hide("/p", "soak", "snoozed", at: SNOOZED)

  # A run of soak running from `at`; its id.
  def start_a_run(at) = @runs.claim(SOAK, commit: COMMIT, lock_file: "/soak.lock", now: at)
end
