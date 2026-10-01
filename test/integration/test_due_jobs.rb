# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/persistence/job_runs"
require "fun_ci/jobs/due_jobs"
require "tmpdir"

# Which of a project's jobs a commit starts: those due, read before anything
# forks (acceptance-tests.md, AT-13.7).
class TestDueJobs < Minitest::Test
  include DatabaseTestSetup

  NOW = Time.utc(2026, 10, 1, 12)

  def setup
    setup_test_db
    @project = File.join(@dir, "project")
    %w[daily/mutation.sh weekly/soak.sh].each { |script| write_job(script) }
  end

  def teardown = teardown_test_db

  def test_should_list_every_job_that_never_ran
    assert_equal %w[mutation soak], due.map(&:name)
  end

  def test_should_leave_out_a_job_that_ran_within_its_period
    FunCi::Persistence::JobRuns.new(@db, @project).claim(soak, commit: { sha: "a", branch: "main" }, lock_file: "/l",
                                                               now: NOW - 3600)

    assert_equal %w[mutation], due.map(&:name)
  end

  def test_should_count_only_the_project_s_own_runs
    FunCi::Persistence::JobRuns.new(@db, "/other").claim(soak, commit: { sha: "a", branch: "main" }, lock_file: "/l",
                                                               now: NOW - 3600)

    assert_equal %w[mutation soak], due.map(&:name)
  end

  # Nothing else would notice: a running job isn't due, so no process starts to find it dead.
  def test_should_list_a_job_left_running_by_a_process_that_died_a_period_ago
    FunCi::Persistence::JobRuns.new(@db, @project).claim(soak, commit: { sha: "a", branch: "main" },
                                                               lock_file: File.join(@dir, "gone.lock"),
                                                               now: NOW - 604_800)

    assert_equal %w[mutation soak], due.map(&:name)
  end

  def test_should_leave_out_a_job_whose_lock_is_held
    FunCi::Persistence::JobRuns.new(@db, @project).claim(soak, commit: { sha: "a", branch: "main" },
                                                               lock_file: held_lock, now: NOW - 604_800)

    assert_equal %w[mutation], due.map(&:name)
  ensure
    @lock&.close
  end

  private

  def held_lock
    path = File.join(@dir, "held.lock")
    @lock = File.open(path, File::RDWR | File::CREAT)
    @lock.flock(File::LOCK_EX)
    path
  end

  def due = FunCi::Jobs::DueJobs.new(@project, @db, now: NOW).list
  def soak = FunCi::Jobs::Folders.new(@project).jobs.last

  def write_job(script)
    path = File.join(@project, ".fun-ci", script)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "#!/bin/sh\n")
    File.chmod(0o755, path)
  end
end
