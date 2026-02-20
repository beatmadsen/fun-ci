# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/database"
require "fun_ci/pipeline_run"
require "tmpdir"

class TestPipelineRunCreate < Minitest::Test
  include DatabaseTestSetup

  def setup
    setup_test_db
  end

  def teardown
    teardown_test_db
  end

  def test_should_create_a_pipeline_run_and_return_its_id
    # Given a commit hash and branch
    # When we create a pipeline run
    id = FunCi::PipelineRun.create(@db, commit_hash: "abc123", branch: "main")
    # Then we should get a positive integer id back
    assert_kind_of Integer, id, "Should return an integer id"
    assert id > 0, "Id should be positive"
  end

  def test_should_default_status_to_scheduled
    # Given a newly created pipeline run
    id = FunCi::PipelineRun.create(@db, commit_hash: "abc123", branch: "main")
    # When we retrieve it
    run = FunCi::PipelineRun.find(@db, id)
    # Then its status should be scheduled
    assert_equal "scheduled", run[:status], "New pipeline run should default to scheduled"
  end

  def test_should_set_created_at_timestamp
    # Given a newly created pipeline run
    id = FunCi::PipelineRun.create(@db, commit_hash: "abc123", branch: "main")
    # When we retrieve it
    run = FunCi::PipelineRun.find(@db, id)
    # Then created_at should be present
    refute_nil run[:created_at], "Should set created_at timestamp"
  end
end

class TestPipelineRunFind < Minitest::Test
  include DatabaseTestSetup

  def setup
    setup_test_db
  end

  def teardown
    teardown_test_db
  end

  def test_should_find_pipeline_run_by_id
    # Given a created pipeline run
    id = FunCi::PipelineRun.create(@db, commit_hash: "abc123", branch: "main")
    # When we find it by id
    run = FunCi::PipelineRun.find(@db, id)
    # Then it should have the correct attributes
    assert_equal "abc123", run[:commit_hash], "Should store commit hash"
    assert_equal "main", run[:branch], "Should store branch"
  end

  def test_should_return_nil_when_id_not_found
    # Given no pipeline runs exist
    # When we try to find a non-existent id
    run = FunCi::PipelineRun.find(@db, 99999)
    # Then it should return nil
    assert_nil run, "Should return nil for non-existent id"
  end

  def test_should_find_pipeline_runs_by_branch
    # Given two runs on main and one on feature
    FunCi::PipelineRun.create(@db, commit_hash: "aaa", branch: "main")
    FunCi::PipelineRun.create(@db, commit_hash: "bbb", branch: "main")
    FunCi::PipelineRun.create(@db, commit_hash: "ccc", branch: "feature")
    # When we find by branch main
    runs = FunCi::PipelineRun.find_by_branch(@db, "main")
    # Then we should get two results
    assert_equal 2, runs.size, "Should find two runs for branch main"
  end

  def test_should_find_pipeline_runs_by_commit
    # Given a run with a specific commit
    FunCi::PipelineRun.create(@db, commit_hash: "abc123", branch: "main")
    FunCi::PipelineRun.create(@db, commit_hash: "def456", branch: "main")
    # When we find by commit
    runs = FunCi::PipelineRun.find_by_commit(@db, "abc123")
    # Then we should get one result with the right commit
    assert_equal 1, runs.size, "Should find one run for commit abc123"
    assert_equal "abc123", runs.first[:commit_hash], "Should match the commit hash"
  end
end

class TestPipelineRunUpdateStatus < Minitest::Test
  include DatabaseTestSetup

  def setup
    setup_test_db
  end

  def teardown
    teardown_test_db
  end

  def test_should_update_status
    # Given a scheduled pipeline run
    id = FunCi::PipelineRun.create(@db, commit_hash: "abc123", branch: "main")
    # When we update the status to running
    FunCi::PipelineRun.update_status(@db, id, "running")
    # Then the status should be running
    run = FunCi::PipelineRun.find(@db, id)
    assert_equal "running", run[:status], "Should update status to running"
  end

  def test_should_update_updated_at_when_status_changes
    # Given a scheduled pipeline run
    id = FunCi::PipelineRun.create(@db, commit_hash: "abc123", branch: "main")
    FunCi::PipelineRun.find(@db, id)
    # When we update the status
    FunCi::PipelineRun.update_status(@db, id, "running")
    # Then updated_at should change
    updated = FunCi::PipelineRun.find(@db, id)
    refute_nil updated[:updated_at], "Should set updated_at"
  end
end

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
