# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/git_project"
require_relative "../../support/process_deadline"
require "fun_ci/pipeline/pipeline_forker"
require "fun_ci/persistence/database"
require "fun_ci/persistence/job_runs"

# The post-commit hook's `trigger --background` starts the project's due
# jobs beside the run (acceptance-tests.md, AT-13.7). Apart from
# test_pipeline_forker.rb, whose tests start no jobs, so that a mutant of
# the jobs' code runs this file alone of the two.
class TestPipelineForkerJobs < Minitest::Test
  include ProcessDeadline

  def setup
    @dir = Dir.mktmpdir("pipeline-forker-jobs")
    @db_path = File.join(@dir, "db.sqlite3")
    FunCi::Persistence::Database.connection(@db_path).tap { |db| FunCi::Persistence::Database.migrate!(db) }.close
    @project = GitProject.create
  end

  def teardown
    FileUtils.rm_rf(@dir)
    @project.remove
  end

  def test_should_start_the_project_s_due_jobs_beside_the_run
    @project.write_stage_scripts { "exit 0" }
    @project.write(".fun-ci/daily/mutation.sh", "#!/bin/sh\n", mode: 0o755)
    forked_to_the_end(@project.commit("Add stages and a daily job"))

    assert_equal "completed", job_status("mutation")
  end

  private

  # Every process the run forks, the job's included, inherits a pipe this
  # holds, whose end comes when the last of them has exited.
  def forked_to_the_end(sha)
    ended, held = IO.pipe
    Dir.chdir(@project.dir) do
      FunCi::Pipeline::PipelineForker.fork_pipeline(commit_hash: sha, branch: "main", db_path: @db_path)
    end
    held.close
    within_deadline { ended.read }
  end

  def job_status(name)
    db = FunCi::Persistence::Database.connection(@db_path)
    FunCi::Persistence::JobRuns.new(db, Dir.chdir(@project.dir) { Dir.pwd }).latest(name)&.dig(:status)
  ensure
    db&.close
  end
end
