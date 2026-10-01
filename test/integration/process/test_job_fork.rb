# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/git_project"
require_relative "../../support/process_deadline"
require "fun_ci/pipeline/pipeline_forker"
require "fun_ci/persistence/database"
require "fun_ci/persistence/job_runs"

# The post-commit hook's `trigger --background` starts each due job of the
# project in a process of its own, beside the pipeline, which runs it in the
# job's own worktree, checked out at the commit (acceptance-tests.md, AT-13.7, AT-13.8).
class TestJobFork < Minitest::Test
  include ProcessDeadline

  # What the job's script writes down: its name, where it runs, its commit and its session.
  TOLD = "$FUN_CI_JOB $(pwd -P) $1 $(ruby -e 'print Process.getsid')"

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

  def test_should_record_the_job_run_on_the_commit
    forked_to_the_end

    assert_equal ["completed", @sha], latest.values_at(:status, :commit_hash)
  end

  def test_should_tell_the_job_its_name
    forked_to_the_end

    assert_equal "mutation", File.read(seen).split[0]
  end

  def test_should_run_the_job_in_its_own_worktree
    forked_to_the_end

    assert_equal File.join(@project.common_dir, "fun-ci", "jobs", "mutation"), File.read(seen).split[1]
  end

  def test_should_give_the_job_the_commit
    forked_to_the_end

    assert_equal @sha, File.read(seen).split[2]
  end

  # So that closing the terminal of the commit doesn't end a job that can run for hours.
  def test_should_run_the_job_in_a_session_of_its_own
    forked_to_the_end

    refute_equal Process.getsid.to_s, File.read(seen).split[3]
  end

  # As when mutineer runs the tests: $stdout and $stderr are StringIOs, not the process's own streams.
  def test_should_run_the_job_while_the_caller_s_streams_are_no_files
    capture_io { forked_to_the_end }

    assert_path_exists seen
  end

  def test_should_start_no_job_that_is_not_due
    forked_to_the_end
    File.delete(seen)
    forked_to_the_end

    refute_path_exists seen
  end

  private

  def seen = File.join(@dir, "seen")

  # Every process the trigger forks inherits a pipe this holds, whose end
  # comes when the last of them, the job's included, has exited.
  def forked_to_the_end
    ended, held = IO.pipe
    Dir.chdir(@project.dir) do
      FunCi::Pipeline::PipelineForker.fork_pipeline(commit_hash: @sha, branch: "main", db_path: @db_path)
    end
    held.close
    within_deadline { ended.read }
  end

  def latest
    db = FunCi::Persistence::Database.connection(@db_path)
    FunCi::Persistence::JobRuns.new(db, Dir.chdir(@project.dir) { Dir.pwd }).latest("mutation")
  ensure
    db&.close
  end
end
