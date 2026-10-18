# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"

# The runs the console builds its rows from: each branch's newest run, and a
# branch's runs newest first.
class TestPipelineRunBranches < Minitest::Test
  include DatabaseTestSetup

  T0 = Time.utc(2026, 10, 19, 9)

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

    assert_equal %w[a2 b1], shas(FunCi::Persistence::PipelineRun.branch_heads(@db, limit: 10, among: 10))
  end

  def test_should_tell_apart_same_named_branches_of_different_projects
    create("a1", "main", "/src/one")
    create("b1", "main", "/src/two")

    assert_equal %w[b1 a1], shas(FunCi::Persistence::PipelineRun.branch_heads(@db, limit: 10, among: 10))
  end

  def test_should_give_at_most_the_limit_of_branches
    %w[one two three].each { |branch| create(branch, branch) }

    assert_equal %w[three two], shas(FunCi::Persistence::PipelineRun.branch_heads(@db, limit: 2, among: 10))
  end

  def test_should_give_a_failed_branch_before_newer_branches_that_passed
    failed = create("f1", "old")
    FunCi::Persistence::PipelineRun.update_status(@db, failed, "failed")
    %w[one two].each { |branch| FunCi::Persistence::PipelineRun.update_status(@db, create(branch, branch), "completed") }

    assert_equal %w[f1 two], shas(FunCi::Persistence::PipelineRun.branch_heads(@db, limit: 2, among: 10))
  end

  def test_should_leave_out_branches_beyond_those_whose_newest_runs_changed_most_recently
    failed = create("f1", "old")
    FunCi::Persistence::PipelineRun.update_status(@db, failed, "failed", at: T0)
    FunCi::Persistence::PipelineRun.update_status(@db, create("one", "one"), "completed", at: T0 + 1)
    FunCi::Persistence::PipelineRun.update_status(@db, create("two", "two"), "completed", at: T0 + 2)

    assert_equal %w[two one], shas(FunCi::Persistence::PipelineRun.branch_heads(@db, limit: 10, among: 2))
  end

  def test_should_count_a_branch_by_when_its_newest_run_last_changed_not_when_it_started
    old = create("f1", "old")
    FunCi::Persistence::PipelineRun.update_status(@db, create("one", "one"), "completed", at: T0 + 1)
    FunCi::Persistence::PipelineRun.update_status(@db, create("two", "two"), "completed", at: T0 + 2)
    FunCi::Persistence::PipelineRun.update_status(@db, old, "failed", at: T0 + 3)

    assert_equal %w[f1 two], shas(FunCi::Persistence::PipelineRun.branch_heads(@db, limit: 10, among: 2))
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
