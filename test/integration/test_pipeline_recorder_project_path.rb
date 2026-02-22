# frozen_string_literal: true

require_relative "../test_helper"
require "tmpdir"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_recorder"
require "fun_ci/persistence/pipeline_run"

class TestDbRecorderProjectPath < Minitest::Test
  include DatabaseTestSetup

  def setup
    setup_test_db
    @recorder = FunCi::Persistence::DbRecorder.new(@db)
  end

  def teardown
    teardown_test_db
  end

  def test_should_store_project_path_when_creating_run
    # Given a recorder
    # When we create a run with project_path
    @recorder.create_run(commit_hash: "abc1234", branch: "main", project_path: "/home/user/my-app")
    # Then the pipeline run should have the project_path stored
    run = FunCi::Persistence::PipelineRun.find(@db, @recorder.pipeline_run_id)
    assert_equal "/home/user/my-app", run[:project_path], "Should store project_path via recorder"
  end

  def test_should_work_without_project_path_for_backward_compatibility
    # Given a recorder
    # When we create a run without project_path
    @recorder.create_run(commit_hash: "abc1234", branch: "main")
    # Then it should work without error and project_path should be nil
    run = FunCi::Persistence::PipelineRun.find(@db, @recorder.pipeline_run_id)
    assert_nil run[:project_path], "Should default project_path to nil"
  end
end
