# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/persistence/job_runs"
require "fun_ci/persistence/active_jobs"
require "fun_ci/persistence/raw_outputs"
require "fun_ci/jobs/job"

# Each job keeps its 10 newest runs (acceptance-tests.md, AT-13.12).
class TestJobRunsRetention < Minitest::Test
  include DatabaseTestSetup

  NOW = Time.utc(2026, 10, 1, 12)
  MUTATION = FunCi::Jobs::Job.new(name: "mutation", cadence: "daily", script: "/p/.fun-ci/daily/mutation.sh")
  COMMIT = { sha: "a" * 40, branch: "main" }.freeze

  def setup
    setup_test_db
    @runs = FunCi::Persistence::JobRuns.new(@db, "/p")
    @raw = FunCi::Persistence::RawOutputs.for_jobs(@db.filename("main"))
  end

  def teardown = teardown_test_db

  def test_should_keep_ten_runs_of_a_job_when_an_eleventh_is_claimed
    cancelled_runs(11)

    assert_equal 10, @db.execute("SELECT COUNT(*) FROM job_runs").first.first
  end

  def test_should_forget_the_oldest_run_of_a_job_when_an_eleventh_is_claimed
    first = cancelled_runs(11).first

    assert_empty @db.execute("SELECT id FROM job_runs WHERE id = ?", [first])
  end

  def test_should_delete_the_raw_output_of_a_run_it_forgets
    first = cancelled_runs(1).first
    @raw.write(first, "the oldest run's output")
    cancelled_runs(10)

    assert_nil @raw.read(first)
  end

  def test_should_keep_the_raw_output_of_a_run_it_keeps
    first = cancelled_runs(1).first
    @raw.write(first, "the oldest run's output")
    cancelled_runs(9)

    assert_equal "the oldest run's output", @raw.read(first)
  end

  def test_should_keep_another_job_s_runs
    other = FunCi::Jobs::Job.new(name: "soak", cadence: "weekly", script: "/p/.fun-ci/weekly/soak.sh")
    @runs.claim(other, commit: COMMIT, lock_file: "/l", now: NOW)
    cancelled_runs(11)

    refute_nil @runs.latest("soak")
  end

  private

  def cancelled_runs(count) = Array.new(count) { cancelled_run }

  def cancelled_run
    id = @runs.claim(MUTATION, commit: COMMIT, lock_file: "/l", now: NOW)
    FunCi::Persistence::ActiveJobs.cancelled(@db, id)
    id
  end
end
