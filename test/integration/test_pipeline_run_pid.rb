# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/database"
require "fun_ci/pipeline_run"
require "tmpdir"

class TestPipelineRunPid < Minitest::Test
  include DatabaseTestSetup

  def setup
    setup_test_db
  end

  def teardown
    teardown_test_db
  end

  def test_should_store_and_retrieve_pid_for_pipeline_run
    # Given a pipeline run exists
    id = FunCi::PipelineRun.create(@db, commit_hash: "abc123", branch: "main")
    # When we store a PID for it
    FunCi::PipelineRun.store_pid(@db, id, 12345)
    # Then the PID should be retrievable
    run = FunCi::PipelineRun.find(@db, id)
    assert_equal 12345, run[:pid], "Should store and retrieve the background PID"
  end

  def test_should_default_pid_to_nil
    # Given a newly created pipeline run
    id = FunCi::PipelineRun.create(@db, commit_hash: "abc123", branch: "main")
    # When we retrieve it
    run = FunCi::PipelineRun.find(@db, id)
    # Then pid should be nil
    assert_nil run[:pid], "New pipeline run should have nil PID"
  end

  def test_should_find_running_pipeline_with_pid_by_branch
    # Given a running pipeline with a PID on branch "main"
    id = FunCi::PipelineRun.create(@db, commit_hash: "abc123", branch: "main")
    FunCi::PipelineRun.update_status(@db, id, "running")
    FunCi::PipelineRun.store_pid(@db, id, 12345)
    # When we look for a running pipeline on "main"
    run = FunCi::PipelineRun.find_running_with_pid(@db, "main")
    # Then we should find it with its PID
    assert_equal id, run[:id], "Should find the running pipeline"
    assert_equal 12345, run[:pid], "Should include the PID"
  end

  def test_should_return_nil_when_no_running_pipeline_on_branch
    # Given a completed pipeline on "main"
    id = FunCi::PipelineRun.create(@db, commit_hash: "abc123", branch: "main")
    FunCi::PipelineRun.update_status(@db, id, "completed")
    # When we look for a running pipeline on "main"
    run = FunCi::PipelineRun.find_running_with_pid(@db, "main")
    # Then we should get nil
    assert_nil run, "Should not find completed pipelines"
  end
end
