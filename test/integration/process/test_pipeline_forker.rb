# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/git_project"
require_relative "../../support/process_deadline"
require "fun_ci/pipeline/pipeline_forker"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"

# `trigger --background` hands the run to PipelineForker, which starts one
# only in a project set up for fun-ci, and says whether it did (AT-9.14).
class TestPipelineForker < Minitest::Test
  include ProcessDeadline

  def setup
    @dir = Dir.mktmpdir("pipeline-forker")
    @db_path = File.join(@dir, "db.sqlite3")
    FunCi::Persistence::Database.connection(@db_path).tap { |db| FunCi::Persistence::Database.migrate!(db) }.close
  end

  def teardown
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
    started = Dir.chdir(@project.dir) { forked(sha) }
    within_deadline { started.join }

    assert_equal "completed", recorded_status(sha)
  end

  private

  def project_passing_every_stage
    @project = GitProject.create
    @project.write_stage_scripts { "exit 0" }
    @project.commit("Add stages")
  end

  def forked(sha) = FunCi::Pipeline::PipelineForker.fork_pipeline(commit_hash: sha, branch: "main", db_path: @db_path)

  def recorded_status(sha)
    db = FunCi::Persistence::Database.connection(@db_path)
    FunCi::Persistence::PipelineRun.find_by_commit(db, sha).first[:status]
  ensure
    db&.close
  end
end
