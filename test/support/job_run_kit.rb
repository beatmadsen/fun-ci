# frozen_string_literal: true

require "tmpdir"
require "fun_ci/persistence/database"
require "fun_ci/persistence/job_runs"
require "fun_ci/jobs/job_run"
require "fun_ci/pipeline/slot_lock"
require "fun_ci/pipeline/worktrees"
require_relative "fake_stage_dir"

# A project with the daily job `mutation`, a database, the job's lock
# directory and worktrees that remember what they checked out, for tests of
# Jobs::JobRun.
module JobRunKit
  SHA = "a" * 40
  PASSED = ["", FakeStatus.new(true, 0)].freeze
  NOW = Time.utc(2026, 10, 1, 12)

  # Remembers each [path, sha] checked out, or raises the error it was told to.
  class FakeWorktrees
    attr_reader :checked_out

    def initialize
      @checked_out = []
    end

    def fail_with(message, error: FunCi::Pipeline::Worktrees::GitError) = @error = error.new(message)

    def check_out(path, sha)
      raise @error if @error

      @checked_out << [path, sha]
    end
  end

  def setup
    @dir = Dir.mktmpdir
    write_script(File.join(project, ".fun-ci", "daily", "mutation.sh"))
    @db = FunCi::Persistence::Database.connection(File.join(@dir, "db.sqlite3"))
    FunCi::Persistence::Database.migrate!(@db)
    @worktrees = FakeWorktrees.new
  end

  def teardown
    @db.close
    FileUtils.remove_entry(@dir)
  end

  def run_job(runner: ->(_cmd) { PASSED })
    seams = FunCi::Pipeline::Seams.new(command_runner: runner, stage_dir: -> { FakeStageDir.new }, environment: {})
    FunCi::Jobs::JobRun.new(job, FunCi::Pipeline::Commit.new(sha: SHA, branch: "main"), site, seams).start
  end

  def project = File.join(@dir, "project")
  def locks_root = File.join(@dir, "jobs")
  def job = FunCi::Jobs::Folders.new(project).jobs.first
  def runs = FunCi::Persistence::JobRuns.new(@db, project)
  def latest = runs.latest("mutation")
  def status_of(id) = @db.execute("SELECT status FROM job_runs WHERE id = ?", [id]).first.first

  def site
    FunCi::Jobs::Site.new(project: project, db: @db, worktrees: @worktrees,
                          locks: FunCi::Jobs::Locks.new(locks_root), clock: -> { NOW })
  end

  def claim_a_run_nobody_runs
    runs.claim(job, commit: { sha: SHA, branch: "main" }, lock_file: "/gone.lock", now: NOW - 86_400)
  end

  # The commit's own copy of the script, in the job's worktree.
  def commit_a_copy_of_the_script
    write_script(File.join(locks_root, "mutation", ".fun-ci", "daily", "mutation.sh"))
  end

  # The commit's own .fun-ci/config, in the job's worktree.
  def commit_a_config(text)
    path = File.join(locks_root, "mutation", ".fun-ci", "config")
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, text)
  end

  def holding_the_lock
    FileUtils.mkdir_p(locks_root)
    File.open(File.join(locks_root, "mutation.lock"), File::RDWR | File::CREAT) do |lock|
      lock.flock(File::LOCK_EX)
      yield
    end
  end

  def write_script(path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "#!/bin/sh\n")
    File.chmod(0o755, path)
    path
  end
end
