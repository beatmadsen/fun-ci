# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/trunk_kit"
require "fun_ci/console/trunk_marks"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"
require "fun_ci/persistence/trunk_checks"
require "fun_ci/persistence/trunk_fetches"

# What the console marks of the trunk (design.md, The trunk): a
# branch's standing on its newest run, and the projects whose trunk is stale.
class TestTrunkMarks < Minitest::Test
  include DatabaseTestSetup
  include TrunkKit

  NOW = Time.utc(2026, 9, 29, 10)
  CONFLICTS = MERGE.conflicts(["a.rb"], ahead: 1, behind: 1)

  def setup = setup_test_db
  def teardown = teardown_test_db

  def test_should_give_a_branch_s_newest_run_the_branch_s_standing
    check(begin_run("aaa"), CONFLICTS)

    assert_equal({ branch_state: "conflicts", trunk: "main" }, marked.first[:trunk])
  end

  def test_should_leave_a_branch_s_older_runs_unmarked
    check(begin_run("aaa"), CONFLICTS)
    begin_run("bbb")

    assert_nil marked.last[:trunk]
  end

  def test_should_keep_the_standing_while_the_newest_run_is_being_checked
    check(begin_run("aaa"), CONFLICTS)
    begin_run("bbb")

    assert_equal "conflicts", marked.first[:trunk][:branch_state]
  end

  def test_should_keep_the_standing_when_the_newest_check_could_not_be_made
    check(begin_run("aaa"), CONFLICTS)
    check(begin_run("bbb"), MERGE.unknown("no trunk"))

    assert_equal "conflicts", marked.first[:trunk][:branch_state]
  end

  def test_should_tell_the_same_branch_of_two_projects_apart
    check(begin_run("aaa"), CONFLICTS)
    begin_run("bbb", project: "/other")

    assert_nil marked.first[:trunk]
  end

  def test_should_name_a_project_whose_last_fetch_failed_stale
    begin_run("aaa")
    fetched("fatal: no route", at: NOW)

    assert_equal [{ project: "/project", since: nil }], marks.stale(runs, now: NOW)
  end

  def test_should_name_a_project_fetched_over_an_hour_ago_stale_since_then
    begin_run("aaa")
    fetched(nil, at: NOW - 3601)

    assert_equal [{ project: "/project", since: (NOW - 3601).to_i }], marks.stale(runs, now: NOW)
  end

  def test_should_not_name_a_project_fetched_within_the_hour
    begin_run("aaa")
    fetched(nil, at: NOW - 3600)

    assert_empty marks.stale(runs, now: NOW)
  end

  private

  def marks = FunCi::Console::TrunkMarks.new(@db)
  def runs = FunCi::Persistence::PipelineRun.recent(@db)
  def marked = marks.mark(runs)

  def begin_run(sha, project: "/project")
    FunCi::Persistence::PipelineRun.create(@db, commit_hash: sha, branch: "main", project_path: project)
    sha
  end

  def check(sha, merge)
    FunCi::Persistence::TrunkChecks.new(@db, "/project").record(trunk_check(sha, merge, seen_at: NOW), checked_at: NOW)
  end

  def fetched(error, at:)
    FunCi::Persistence::TrunkFetches.new(@db, "/project").finished(FunCi::Trunk::Fetched.new(error: error), at: at)
  end
end
