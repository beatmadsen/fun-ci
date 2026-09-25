# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"
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
    id = FunCi::Persistence::PipelineRun.create(@db, commit_hash: "abc123", branch: "main")
    FunCi::Persistence::PipelineRun.store_pid(@db, id, 12_345)
    run = FunCi::Persistence::PipelineRun.find(@db, id)
    assert_equal 12_345, run[:pid], "Should store and retrieve the background PID"
  end

  def test_should_default_pid_to_nil
    id = FunCi::Persistence::PipelineRun.create(@db, commit_hash: "abc123", branch: "main")
    run = FunCi::Persistence::PipelineRun.find(@db, id)
    assert_nil run[:pid], "New pipeline run should have nil PID"
  end
end
