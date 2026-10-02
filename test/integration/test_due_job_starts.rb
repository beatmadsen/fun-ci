# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/persistence/job_runs"
require "fun_ci/jobs/due_jobs"
require "tmpdir"

# When each job a commit starts begins (Jobs::Schedule, AT-13.28), read
# with the jobs that are due: a day shared evenly among the project's jobs,
# or the project's `job_spacing`, apart, after any of its jobs still running
# or waiting to.
class TestDueJobStarts < Minitest::Test
  include DatabaseTestSetup

  NOW = Time.utc(2026, 10, 2, 12)

  def setup
    setup_test_db
    @project = File.join(@dir, "project")
    %w[daily/asan.sh daily/fuzz.sh weekly/soak.sh].each { |script| write(".fun-ci/#{script}", "#!/bin/sh\n") }
  end

  def teardown = teardown_test_db

  # Three jobs share a day: eight hours each.
  def test_should_spread_the_due_jobs_evenly_over_a_day_when_nothing_says_otherwise
    assert_equal [NOW, NOW + 28_800, NOW + 57_600], starts.map(&:last)
  end

  def test_should_start_the_due_jobs_as_far_apart_as_the_config_says
    write(".fun-ci/config", "job_spacing: 1m\n")

    assert_equal [NOW, NOW + 60, NOW + 120], starts.map(&:last)
  end

  def test_should_start_after_a_job_still_running
    File.open(File.join(@dir, "soak.lock"), File::RDWR | File::CREAT) do |lock|
      lock.flock(File::LOCK_EX)
      FunCi::Persistence::JobRuns.new(@db, @project).claim(job("soak"), commit: { sha: "a", branch: "main" },
                                                                        lock_file: lock.path, now: NOW - 60)

      assert_equal [NOW - 60 + 28_800, NOW - 60 + 57_600], starts.map(&:last)
    end
  end

  private

  def starts = FunCi::Jobs::DueJobs.new(@project, @db, now: NOW).starts
  def job(name) = FunCi::Jobs::Folders.new(@project).jobs.find { |found| found.name == name }

  def write(path, content)
    full = File.join(@project, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
    File.chmod(0o755, full)
  end
end
