# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/jobs/standings"
require "fun_ci/persistence/database"
require "fun_ci/persistence/active_jobs"
require "fun_ci/persistence/job_recorder"

# Where each of a project's jobs stands: its latest run, its state, and when
# it is due, read once for the console, the agent commands and the trigger
# (design.md, Daily and weekly jobs).
class TestJobStandings < Minitest::Test
  include DatabaseTestSetup

  NOW = Time.utc(2026, 10, 1, 12)

  def setup
    setup_test_db
    @project = File.join(@dir, "project")
    %w[daily/mutation.sh weekly/soak.sh].each { |script| write_job(script) }
  end

  def teardown = teardown_test_db

  def test_should_list_the_project_s_jobs_by_name
    assert_equal(%w[mutation soak], standings.map { |standing| standing.job.name })
  end

  def test_should_say_a_job_that_never_ran_is_due
    assert_equal "due", standing("mutation").state
  end

  def test_should_say_a_job_that_never_ran_is_due_now
    assert_predicate standing("mutation"), :due_now?
  end

  def test_should_carry_the_job_s_latest_run
    id = claim("mutation", NOW - 60)

    assert_equal id, standing("mutation").run[:id]
  end

  def test_should_say_how_the_job_s_latest_run_ended
    FunCi::Persistence::JobRecorder.new(@db).end_stage(claim("soak", NOW - 60), "failed")

    assert_equal "failed", standing("soak").state
  end

  def test_should_say_when_a_job_is_due_again
    FunCi::Persistence::JobRecorder.new(@db).end_stage(claim("soak", NOW - 3600), "completed")

    assert_equal Time.utc(2026, 10, 8, 11), standing("soak").due_at
  end

  def test_should_say_a_job_whose_latest_run_was_cancelled_is_due_now
    FunCi::Persistence::ActiveJobs.cancelled(@db, claim("soak", NOW - 60))

    assert_predicate standing("soak"), :due_now?
  end

  def test_should_say_a_running_job_is_not_due_now
    claim("soak", NOW - (2 * 604_800))

    refute_predicate standing("soak"), :due_now?
  end

  def test_should_say_which_project_a_job_belongs_to
    assert_equal @project, standing("soak").project
  end

  private

  def standings = FunCi::Jobs::Standings.new(@db, @project, now: NOW).all
  def standing(name) = standings.find { |found| found.job.name == name }

  def claim(name, at)
    job = FunCi::Jobs::Folders.new(@project).jobs.find { |found| found.name == name }
    FunCi::Persistence::JobRuns.new(@db, @project).claim(job, commit: { sha: "a" * 40, branch: "main" },
                                                              lock_file: "/l", now: at)
  end

  def write_job(script)
    path = File.join(@project, ".fun-ci", script)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "#!/bin/sh\n")
    File.chmod(0o755, path)
  end
end
