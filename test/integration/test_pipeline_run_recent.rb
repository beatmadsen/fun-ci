# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/database"
require "fun_ci/pipeline_run"
require "tmpdir"

class TestPipelineRunRecent < Minitest::Test
  include DatabaseTestSetup

  def setup
    setup_test_db
  end

  def teardown
    teardown_test_db
  end

  def test_should_list_recent_runs_ordered_by_newest_first
    # Given three pipeline runs created in order
    id1 = FunCi::PipelineRun.create(@db, commit_hash: "aaa", branch: "main")
    FunCi::PipelineRun.create(@db, commit_hash: "bbb", branch: "main")
    id3 = FunCi::PipelineRun.create(@db, commit_hash: "ccc", branch: "main")
    # When we list recent runs
    runs = FunCi::PipelineRun.recent(@db)
    # Then they should be ordered newest first
    assert_equal id3, runs.first[:id], "Most recent run should be first"
    assert_equal id1, runs.last[:id], "Oldest run should be last"
  end

  def test_should_limit_recent_runs
    # Given 5 pipeline runs
    5.times { |i| FunCi::PipelineRun.create(@db, commit_hash: "hash#{i}", branch: "main") }
    # When we list recent with limit 3
    runs = FunCi::PipelineRun.recent(@db, limit: 3)
    # Then we should get exactly 3
    assert_equal 3, runs.size, "Should respect the limit"
  end
end
