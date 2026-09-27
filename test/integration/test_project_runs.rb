# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/persistence/project_runs"

# The runs of one project, which shares its database with every other.
class TestProjectRuns < Minitest::Test
  include DatabaseTestSetup

  RUN = FunCi::Persistence::PipelineRun

  def setup
    setup_test_db
    @runs = FunCi::Persistence::ProjectRuns.new(@db, "/project")
  end

  def teardown = teardown_test_db

  def test_should_find_the_newest_run_of_a_commit
    record("abc1234")
    newest = record("abc1234")

    assert_equal newest, @runs.latest_of_commit("abc1234")[:id]
  end

  def test_should_not_find_another_project_s_run_of_the_same_commit
    record("abc1234", project: "/elsewhere")

    assert_nil @runs.latest_of_commit("abc1234")
  end

  def test_should_name_the_first_newer_commit_on_the_run_s_branch
    old = record("abc1234")
    record("fff0000", branch: "feature")
    record("bcd2345")
    record("cde3456")

    assert_equal "bcd2345", @runs.superseded_by(RUN.find(@db, old))
  end

  def test_should_name_no_newer_commit_for_the_newest_run_on_its_branch
    old = record("abc1234")
    record("bcd2345", project: "/elsewhere")

    assert_nil @runs.superseded_by(RUN.find(@db, old))
  end

  private

  def record(sha, branch: "main", project: "/project")
    RUN.create(@db, commit_hash: sha, branch: branch, project_path: project)
  end
end
