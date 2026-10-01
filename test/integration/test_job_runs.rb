# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/persistence/job_runs"
require "fun_ci/jobs/job"

# Claiming and reading a project's job runs (acceptance-tests.md, AT-13.4, AT-13.6).
class TestJobRuns < Minitest::Test
  include DatabaseTestSetup

  NOW = Time.utc(2026, 10, 1, 12)
  DAY = 86_400
  MUTATION = FunCi::Jobs::Job.new(name: "mutation", cadence: "daily", script: "/p/.fun-ci/daily/mutation.sh")
  COMMIT = { sha: "a" * 40, branch: "main" }.freeze

  def setup
    setup_test_db
    @runs = FunCi::Persistence::JobRuns.new(@db, "/p")
  end

  def teardown = teardown_test_db

  def test_should_claim_a_job_that_never_ran
    assert claim(NOW)
  end

  def test_should_record_a_claimed_run_running
    claim(NOW)

    assert_equal "running", @runs.latest("mutation")[:status]
  end

  def test_should_record_the_commit_a_claimed_run_tests
    claim(NOW)

    assert_equal ["a" * 40, "main"], @runs.latest("mutation").values_at(:commit_hash, :branch)
  end

  def test_should_record_the_lock_a_claimed_run_holds
    claim(NOW)

    assert_equal "/locks/mutation.lock", @runs.latest("mutation")[:lock_file]
  end

  def test_should_not_claim_a_job_a_second_time_while_it_runs
    claim(NOW)

    refute claim(NOW + (2 * DAY))
  end

  def test_should_not_claim_a_job_before_its_period_has_passed
    finish(claim(NOW), "completed")

    refute claim(NOW + DAY - 1)
  end

  def test_should_claim_a_job_again_once_its_period_has_passed
    finish(claim(NOW), "completed")

    assert claim(NOW + DAY)
  end

  def test_should_claim_a_job_again_at_once_when_its_latest_run_was_cancelled
    @runs.cancelled(claim(NOW))

    assert claim(NOW + 60)
  end

  def test_should_not_count_another_project_s_run_of_a_job_of_the_same_name
    claim(NOW)

    assert FunCi::Persistence::JobRuns.new(@db, "/other").claim(MUTATION, commit: COMMIT, lock_file: "/l", now: NOW)
  end

  def test_should_record_failed_the_running_runs_of_a_job_whose_lock_nobody_holds
    claim(NOW)
    @runs.died("mutation")

    assert_equal "failed", @runs.latest("mutation")[:status]
  end

  def test_should_leave_a_finished_run_as_it_is_when_its_job_died
    finish(claim(NOW), "completed")
    @runs.died("mutation")

    assert_equal "completed", @runs.latest("mutation")[:status]
  end

  def test_should_leave_a_cancelled_run_cancelled_when_it_ends_after_the_cancel
    id = claim(NOW)
    @runs.cancelled(id)
    finish(id, "failed")

    assert_equal "cancelled", @runs.latest("mutation")[:status]
  end

  def test_should_know_no_latest_run_of_a_job_that_never_ran
    assert_nil @runs.latest("mutation")
  end

  private

  def claim(now) = @runs.claim(MUTATION, commit: COMMIT, lock_file: "/locks/mutation.lock", now: now)
  def finish(id, status) = @runs.finished(id, status)
end
