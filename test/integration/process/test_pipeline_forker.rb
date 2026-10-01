# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/git_project"
require_relative "../../support/process_deadline"
require "fun_ci/pipeline/pipeline_forker"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"
require "fun_ci/persistence/stage_job"

# `trigger --background` hands the run to PipelineForker, which starts one
# only in a project set up for fun-ci, and says whether it did (AT-9.14).
class TestPipelineForker < Minitest::Test
  include ProcessDeadline

  # What starts the jobs here, unless a test says otherwise: nothing.
  # Mutineer runs every file that covers a mutant within 10 s, so the real
  # jobs start in test_pipeline_forker_jobs.rb, apart from these tests.
  NO_JOBS = ->(*) {}

  def setup
    @dir = Dir.mktmpdir("pipeline-forker")
    @db_path = File.join(@dir, "db.sqlite3")
    FunCi::Persistence::Database.connection(@db_path).tap { |db| FunCi::Persistence::Database.migrate!(db) }.close
  end

  def teardown
    release_the_slow_suite
    FileUtils.rm_rf(@dir)
    @project&.remove
  end

  def test_should_start_no_run_in_a_project_without_fun_ci
    started = Dir.chdir(@dir) { FunCi::Pipeline::PipelineForker.fork_pipeline(commit_hash: "abc1234", branch: "main", db_path: @db_path) }

    assert_equal false, started
  end

  # What the post-commit hook's `trigger --background` leaves running: the
  # whole pipeline, slow suite included, in a child of its own; a run whose
  # four stages passed is recorded completed.
  def test_should_run_and_record_the_pipeline_for_the_commit_in_a_child
    sha = project_passing_every_stage
    forked_to_the_end(sha)

    assert_equal "completed", recorded_status(sha)
  end

  # The slow suite reads a FIFO the fast suite writes, so it can end only once
  # the fast suite has run; which of the two is recorded first is theirs to race.
  def test_should_run_the_fast_suite_while_the_slow_suite_runs_in_the_background
    sha = project_whose_slow_suite_waits_for_the_fast_suite
    forked_to_the_end(sha)

    assert_operator stage(sha, "fast")[:started_at], :<, stage(sha, "slow")[:completed_at]
  end

  # A job is no part of a run: trouble starting the jobs never costs the commit its CI (AT-13.7).
  def test_should_run_the_pipeline_when_the_jobs_cannot_start
    sha = project_passing_every_stage
    forked_to_the_end(sha, jobs: ->(*) { raise SQLite3::BusyException, "database is locked" })

    assert_equal "completed", recorded_status(sha)
  end

  def test_should_say_why_the_jobs_did_not_start
    sha = project_passing_every_stage
    forked = forked_to_the_end(sha, jobs: ->(*) { raise SQLite3::BusyException, "database is locked" })

    assert_equal "fun-ci: the daily and weekly jobs didn't start: database is locked", forked.jobs
  end

  private

  def project_whose_slow_suite_waits_for_the_fast_suite
    @fifo = File.join(@dir, "fast-ran")
    File.mkfifo(@fifo)
    @project = GitProject.create
    bodies = { "slow" => "cat '#{@fifo}' > /dev/null", "fast" => "echo ran > '#{@fifo}'" }
    @project.write_stage_scripts { |stage| bodies.fetch(stage, "exit 0") }
    @project.commit("Add stages")
  end

  # A slow suite still waiting on the fast suite, when the test failed, is let go.
  def release_the_slow_suite
    File.open(@fifo, File::WRONLY | File::NONBLOCK) { |fifo| fifo.write("gave up\n") } if @fifo
  rescue Errno::ENXIO, Errno::ENOENT
    nil
  end

  def stage(sha, name)
    db = FunCi::Persistence::Database.connection(@db_path)
    run = FunCi::Persistence::PipelineRun.find_by_commit(db, sha).first
    FunCi::Persistence::StageJob.for_run(db, run[:id]).find { |job| job[:stage] == name }
  ensure
    db&.close
  end

  def project_passing_every_stage
    @project = GitProject.create
    @project.write_stage_scripts { "exit 0" }
    @project.commit("Add stages")
  end

  # Every process the run forks inherits a pipe this holds, whose end comes
  # when the last of them, the slow suite's included, has exited.
  def forked_to_the_end(sha, jobs: NO_JOBS)
    ended, held = IO.pipe
    forked = Dir.chdir(@project.dir) { forked(sha, jobs: jobs) }
    held.close
    within_deadline { ended.read }
    forked
  end

  def forked(sha, **)
    FunCi::Pipeline::PipelineForker.fork_pipeline(commit_hash: sha, branch: "main", db_path: @db_path, **)
  end

  def recorded_status(sha)
    db = FunCi::Persistence::Database.connection(@db_path)
    FunCi::Persistence::PipelineRun.find_by_commit(db, sha).first[:status]
  ensure
    db&.close
  end
end
