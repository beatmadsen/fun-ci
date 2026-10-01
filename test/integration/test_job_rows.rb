# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/console/job_rows"
require "fun_ci/persistence/database"
require "fun_ci/persistence/job_runs"
require "fun_ci/persistence/active_jobs"
require "fun_ci/persistence/job_recorder"

# The job section's rows: each job of the board's projects, as its latest
# run left it, or due (acceptance-tests.md, AT-13.14).
class TestJobRows < Minitest::Test
  include DatabaseTestSetup

  NOW = Time.utc(2026, 10, 1, 12)

  def setup
    setup_test_db
    @project = File.join(@dir, "project")
    %w[daily/mutation.sh weekly/soak.sh].each { |script| write_job(@project, script) }
  end

  def teardown = teardown_test_db

  def test_should_show_a_job_that_never_ran_due
    assert_equal "due", row("mutation")[:status]
  end

  def test_should_show_a_job_whose_latest_run_was_cancelled_due
    FunCi::Persistence::ActiveJobs.cancelled(@db, claim("mutation", NOW - 60))

    assert_equal "due", row("mutation")[:status]
  end

  def test_should_show_a_job_as_its_latest_run_ended
    finish(claim("mutation", NOW - 60), "failed")

    assert_equal "failed", row("mutation")[:status]
  end

  def test_should_carry_the_latest_run_of_a_job
    id = claim("mutation", NOW - 60)

    assert_equal id, row("mutation")[:run][:id]
  end

  def test_should_say_when_a_job_is_due_again
    finish(claim("soak", NOW - 3600), "completed")

    assert_equal NOW - 3600 + 604_800, row("soak")[:due_at]
  end

  def test_should_say_how_often_a_job_runs
    assert_equal "weekly", row("soak")[:cadence]
  end

  def test_should_list_a_failed_job_before_a_due_one
    finish(claim("soak", NOW - 60), "failed")

    assert_equal(%w[soak mutation], rows.map { |job| job[:name] })
  end

  def test_should_list_no_job_of_a_project_not_on_the_board
    other = File.join(@dir, "other")
    write_job(other, "daily/lint-deep.sh")

    refute_includes rows.map { |job| job[:name] }, "lint-deep"
  end

  private

  def rows = FunCi::Console::JobRows.new(@db).of([@project], now: NOW)
  def row(name) = rows.find { |job| job[:name] == name }
  def finish(id, status) = FunCi::Persistence::JobRecorder.new(@db).end_stage(id, status)

  def claim(name, at)
    job = FunCi::Jobs::Folders.new(@project).jobs.find { |found| found.name == name }
    FunCi::Persistence::JobRuns.new(@db, @project).claim(job, commit: { sha: "a" * 40, branch: "main" },
                                                              lock_file: "/l", now: at)
  end

  def write_job(project, script)
    path = File.join(project, ".fun-ci", script)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "#!/bin/sh\n")
    File.chmod(0o755, path)
  end
end
