# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/pipeline/pipeline_forker"
require "fun_ci/persistence/database"

# `trigger --background` hands the run to PipelineForker, which starts one
# only in a project set up for fun-ci, and says whether it did (AT-9.14).
class TestPipelineForker < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("pipeline-forker")
    @db_path = File.join(@dir, "db.sqlite3")
    FunCi::Persistence::Database.connection(@db_path).tap { |db| FunCi::Persistence::Database.migrate!(db) }.close
  end

  def teardown = FileUtils.rm_rf(@dir)

  def test_should_start_no_run_in_a_project_without_fun_ci
    started = Dir.chdir(@dir) { FunCi::Pipeline::PipelineForker.fork_pipeline(commit_hash: "abc1234", branch: "main", db_path: @db_path) }

    assert_equal false, started
  end
end
