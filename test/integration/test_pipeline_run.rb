# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"
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
    id = FunCi::Persistence::PipelineRun.create(@db, commit_hash: "abc123", branch: "main")
    assert_kind_of Integer, id, "Should return an integer id"
    assert_predicate id, :positive?, "Id should be positive"
  end

  def test_should_default_status_to_scheduled
    id = FunCi::Persistence::PipelineRun.create(@db, commit_hash: "abc123", branch: "main")
    run = FunCi::Persistence::PipelineRun.find(@db, id)
    assert_equal "scheduled", run[:status], "New pipeline run should default to scheduled"
  end

  def test_should_set_created_at_timestamp
    id = FunCi::Persistence::PipelineRun.create(@db, commit_hash: "abc123", branch: "main")
    run = FunCi::Persistence::PipelineRun.find(@db, id)
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
    id = FunCi::Persistence::PipelineRun.create(@db, commit_hash: "abc123", branch: "main")
    run = FunCi::Persistence::PipelineRun.find(@db, id)
    assert_equal "abc123", run[:commit_hash], "Should store commit hash"
    assert_equal "main", run[:branch], "Should store branch"
  end

  def test_should_return_nil_when_id_not_found
    run = FunCi::Persistence::PipelineRun.find(@db, 99_999)
    assert_nil run, "Should return nil for non-existent id"
  end

  def test_should_find_pipeline_runs_by_branch
    FunCi::Persistence::PipelineRun.create(@db, commit_hash: "aaa", branch: "main")
    FunCi::Persistence::PipelineRun.create(@db, commit_hash: "bbb", branch: "main")
    FunCi::Persistence::PipelineRun.create(@db, commit_hash: "ccc", branch: "feature")
    runs = FunCi::Persistence::PipelineRun.find_by_branch(@db, "main")
    assert_equal 2, runs.size, "Should find two runs for branch main"
  end

  def test_should_find_pipeline_runs_by_commit
    FunCi::Persistence::PipelineRun.create(@db, commit_hash: "abc123", branch: "main")
    FunCi::Persistence::PipelineRun.create(@db, commit_hash: "def456", branch: "main")
    runs = FunCi::Persistence::PipelineRun.find_by_commit(@db, "abc123")
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
    id = FunCi::Persistence::PipelineRun.create(@db, commit_hash: "abc123", branch: "main")
    FunCi::Persistence::PipelineRun.update_status(@db, id, "running")
    run = FunCi::Persistence::PipelineRun.find(@db, id)
    assert_equal "running", run[:status], "Should update status to running"
  end

  def test_should_update_updated_at_when_status_changes
    id = FunCi::Persistence::PipelineRun.create(@db, commit_hash: "abc123", branch: "main")
    FunCi::Persistence::PipelineRun.find(@db, id)
    FunCi::Persistence::PipelineRun.update_status(@db, id, "running")
    updated = FunCi::Persistence::PipelineRun.find(@db, id)
    refute_nil updated[:updated_at], "Should set updated_at"
  end
end
