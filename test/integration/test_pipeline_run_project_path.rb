# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"
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
    id = FunCi::Persistence::PipelineRun.create(@db, commit_hash: "abc123", branch: "main",
                                                     project_path: "/home/user/my-app")
    run = FunCi::Persistence::PipelineRun.find(@db, id)
    assert_equal "/home/user/my-app", run[:project_path], "Should store project_path"
  end

  def test_should_default_project_path_to_nil_when_not_provided
    id = FunCi::Persistence::PipelineRun.create(@db, commit_hash: "abc123", branch: "main")
    run = FunCi::Persistence::PipelineRun.find(@db, id)
    assert_nil run[:project_path], "Should default project_path to nil"
  end
end
