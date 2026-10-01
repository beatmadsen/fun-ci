# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/git_project"
require_relative "../../support/process_deadline"
require_relative "../../support/fifo"
require "fun_ci/pipeline/pipeline_forker"
require "fun_ci/persistence/database"
require "fun_ci/persistence/job_runs"

# The post-commit hook's `trigger --background` starts each due job of the
# project in a process of its own, beside the pipeline, which runs it in the
# job's own worktree (acceptance-tests.md, AT-13.7, AT-13.8). Only what
# crosses the fork is here: what the job is told, which jobs are due and
# what a run records are each pinned where they are decided
# (test_job_run.rb, test_due_jobs.rb, test_job_recorder.rb).
class TestJobFork < Minitest::Test
  include ProcessDeadline

  # What the job's script writes down: where it runs, its session and its process group.
  TOLD = "$(pwd -P) $(ruby -e 'print Process.getsid') $(ruby -e 'print Process.getpgrp')"

  def setup
    @dir = Dir.mktmpdir("job-fork")
    @db_path = File.join(@dir, "db.sqlite3")
    FunCi::Persistence::Database.connection(@db_path).tap { |db| FunCi::Persistence::Database.migrate!(db) }.close
    @sha = project_with_a_daily_job
  end

  def project_with_a_daily_job
    @project = GitProject.create
    @project.write_stage_scripts { "exit 0" }
    @project.write(".fun-ci/daily/mutation.sh", "#!/bin/sh\necho \"#{TOLD}\" > '#{seen}'\n", mode: 0o755)
    @project.commit("Add stages and a daily job")
  end

  def teardown
    FileUtils.rm_rf(@dir)
    @project.remove
  end

  def test_should_record_the_job_run_completed
    forked_to_the_end

    assert_equal "completed", latest[:status]
  end

  def test_should_run_the_job_in_its_own_worktree
    forked_to_the_end

    assert_equal File.join(@project.common_dir, "fun-ci", "jobs", "mutation"), told[:worktree]
  end

  # So that closing the terminal of the commit doesn't end a job that can run for hours.
  def test_should_run_the_job_in_a_session_of_its_own
    forked_to_the_end

    refute_equal Process.getsid.to_s, told[:session]
  end

  # As when mutineer runs the tests: $stdout and $stderr are StringIOs, not the process's own streams.
  def test_should_record_the_process_group_the_job_s_script_runs_in
    forked_to_the_end

    assert_equal told[:group].to_i, latest[:group_pid]
  end

  def test_should_run_the_job_while_the_caller_s_streams_are_no_files
    capture_io { forked_to_the_end }

    assert_path_exists seen
  end

  # Its runner gone, a job's script still runs in the job's worktree, so the
  # job must not read as dead and start again there (code review, finding 1).
  def test_should_keep_the_job_s_lock_held_while_its_script_outlives_its_runner
    @sha = job_that_kills_its_runner
    state = nil
    forked_to_the_end { state = within_deadline { Fifo.read(fifo) } }

    assert_equal "held", state
  end

  private

  def fifo = File.join(@dir, "lock-state")

  # What the job's script wrote down (TOLD), by name.
  def told = %i[worktree session group].zip(File.read(seen).split).to_h

  # A job whose script kills the process running it, then says whether the job's lock is still held.
  def job_that_kills_its_runner
    File.mkfifo(fifo)
    lock = '"$(git rev-parse --git-common-dir)/fun-ci/jobs/mutation.lock"'
    look = "ruby -e 'print(File.open(ARGV[0]).flock(File::LOCK_EX | File::LOCK_NB) ? \"free\" : \"held\")'"
    @project.write(".fun-ci/daily/mutation.sh", "#!/bin/sh\nkill -9 $PPID\nsleep 1\n#{look} #{lock} > '#{fifo}'\n",
                   mode: 0o755)
    @project.commit("A job that outlives its runner")
  end

  def seen = File.join(@dir, "seen")

  # Every process the trigger forks inherits a pipe this holds, whose end
  # comes when the last of them, the job's included, has exited.
  # A block given runs once the processes are started, before waiting for them.
  def forked_to_the_end
    ended, held = IO.pipe
    Dir.chdir(@project.dir) do
      FunCi::Pipeline::PipelineForker.fork_pipeline(commit_hash: @sha, branch: "main", db_path: @db_path)
    end
    held.close
    yield if block_given?
    within_deadline { ended.read }
  end

  def latest
    db = FunCi::Persistence::Database.connection(@db_path)
    FunCi::Persistence::JobRuns.new(db, Dir.chdir(@project.dir) { Dir.pwd }).latest("mutation")
  ensure
    db&.close
  end
end
