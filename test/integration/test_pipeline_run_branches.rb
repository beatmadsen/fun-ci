# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"

# The runs the console builds its rows from: each branch's newest run, and a
# branch's runs newest first.
class TestPipelineRunBranches < Minitest::Test
  include DatabaseTestSetup

  def setup
    setup_test_db
  end

  def teardown
    teardown_test_db
  end

  def test_should_give_the_newest_run_of_each_branch_newest_first
    create("a1", "main")
    create("b1", "feat")
    create("a2", "main")

    assert_equal %w[a2 b1], shas(FunCi::Persistence::PipelineRun.branch_heads(@db, limit: 10))
  end

  def test_should_tell_apart_same_named_branches_of_different_projects
    create("a1", "main", "/src/one")
    create("b1", "main", "/src/two")

    assert_equal %w[b1 a1], shas(FunCi::Persistence::PipelineRun.branch_heads(@db, limit: 10))
  end

  def test_should_give_at_most_the_limit_of_branches
    %w[one two three].each { |branch| create(branch, branch) }

    assert_equal %w[three two], shas(FunCi::Persistence::PipelineRun.branch_heads(@db, limit: 2))
  end

  def test_should_give_a_branch_s_runs_newest_first
    create("a1", "main", "/src/one")
    create("b1", "main", "/src/two")
    create("a2", "main", "/src/one")

    assert_equal %w[a2 a1], shas(FunCi::Persistence::PipelineRun.of_branch(@db, "/src/one", "main", limit: 10))
  end

  def test_should_give_the_runs_of_a_branch_with_no_project
    create("a1", "main")
    create("b1", "main", "/src/two")

    assert_equal %w[a1], shas(FunCi::Persistence::PipelineRun.of_branch(@db, nil, "main", limit: 10))
  end

  private

  def create(sha, branch, project = nil)
    FunCi::Persistence::PipelineRun.create(@db, commit_hash: sha, branch: branch, project_path: project)
  end

  def shas(runs) = runs.map { |run| run[:commit_hash] }
end
