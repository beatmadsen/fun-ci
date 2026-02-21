# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/database"
require "fun_ci/pipeline_run"
require "tmpdir"

class TestPipelineRunProjectPath < Minitest::Test
  include DatabaseTestSetup

  def setup
    setup_test_db
  end

  def teardown
    teardown_test_db
  end

  def test_should_store_project_path_when_provided
    # Given a project path
    # When we create a pipeline run with project_path
    id = FunCi::PipelineRun.create(@db, commit_hash: "abc123", branch: "main", project_path: "/home/user/my-app")
    # Then we should be able to retrieve the project_path
    run = FunCi::PipelineRun.find(@db, id)
    assert_equal "/home/user/my-app", run[:project_path], "Should store project_path"
  end

  def test_should_default_project_path_to_nil_when_not_provided
    # Given no project_path
    # When we create a pipeline run without project_path
    id = FunCi::PipelineRun.create(@db, commit_hash: "abc123", branch: "main")
    # Then project_path should be nil
    run = FunCi::PipelineRun.find(@db, id)
    assert_nil run[:project_path], "Should default project_path to nil"
  end
end
