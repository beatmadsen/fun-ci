# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/agent/reports"
require_relative "../support/fake_git"
require_relative "../support/fake_clock"
require "fun_ci/persistence/trunk_checks"
require "fun_ci/persistence/trunk_fetches"
require_relative "../support/trunk_kit"
require_relative "../support/fake_trunk_now"

# A commit's newest run in the project, read into what an agent is told.
class TestAgentReports < Minitest::Test
  include DatabaseTestSetup
  include PipelineTestHelpers
  include TrunkKit

  def setup
    setup_test_db
    git = FakeGit.new("/project")
    git.commit("abc1234", "Add retry")
    @clock = FakeClock.new(now: Time.utc(2026, 9, 29, 10))
    @trunk = FakeTrunkNow.new
    @reports = FunCi::Agent::Reports.new(@db, git, @clock, @trunk)
  end

  def teardown = teardown_test_db

  def test_should_report_the_newest_run_of_the_commit_in_the_project
    run_in_project("abc1234", "failed")
    run_in_project("abc1234", "completed")

    assert_equal :passed, @reports.for("abc1234", "fast").verdict
  end

  def test_should_report_nothing_for_a_commit_without_a_run_in_the_project
    assert_nil @reports.for("abc1234", "fast")
  end

  def test_should_report_how_the_run_s_commit_stands_against_the_trunk
    run_in_project("abc1234", "completed")
    record_trunk_check("abc1234", MERGE.clean(ahead: 0, behind: 1))

    assert_equal "in_trunk", @reports.for("abc1234", "fast").trunk.state
  end

  def test_should_report_no_trunk_for_a_commit_never_checked
    run_in_project("abc1234", "completed")

    assert_nil @reports.for("abc1234", "fast").trunk
  end

  def test_should_report_a_check_begun_and_not_yet_recorded_as_checking
    run = run_in_project("abc1234", "running")
    FunCi::Persistence::PipelineRun.trunk_started(@db, run, @clock.now)

    assert_equal "checking", @reports.for("abc1234", "fast").trunk.state
  end

  def test_should_report_why_the_project_s_last_fetch_of_the_trunk_failed
    run_in_project("abc1234", "completed")
    record_trunk_check("abc1234", MERGE.clean(ahead: 1, behind: 1))
    FunCi::Persistence::TrunkFetches.new(@db, "/project").finished(FunCi::Trunk::Fetched.new(error: "fatal: x"),
                                                                   at: @clock.now)

    assert_equal "fatal: x", @reports.for("abc1234", "fast").trunk.fetch_error
  end

  def test_should_report_where_the_trunk_has_moved_to_since_the_check
    run_in_project("abc1234", "completed")
    record_trunk_check("abc1234", MERGE.clean(ahead: 1, behind: 1))
    @trunk.sha = "1a2b3c4"

    assert_equal "1a2b3c4", @reports.for("abc1234", "fast").trunk.moved_to
  end

  def test_should_report_no_move_while_the_trunk_is_where_it_was_checked
    run_in_project("abc1234", "completed")
    record_trunk_check("abc1234", MERGE.clean(ahead: 1, behind: 1))

    assert_nil @reports.for("abc1234", "fast").trunk.moved_to
  end

  def test_should_check_again_against_where_the_trunk_is_now
    run_in_project("abc1234", "completed")
    record_trunk_check("abc1234", MERGE.conflicts(["a.rb"], ahead: 1, behind: 1))
    @trunk.sha = "1a2b3c4"
    @trunk.merge = MERGE.clean(ahead: 1, behind: 2)
    @reports.recheck_trunk("abc1234")

    assert_equal "clean", @reports.for("abc1234", "fast").trunk.state
  end

  def test_should_keep_nothing_when_the_project_checks_no_trunk_any_more
    run_in_project("abc1234", "completed")
    record_trunk_check("abc1234", MERGE.conflicts(["a.rb"], ahead: 1, behind: 1))
    @trunk.sha = "1a2b3c4"
    @reports.recheck_trunk("abc1234")

    assert_equal "conflicts", @reports.for("abc1234", "fast").trunk.state
  end

  def test_should_take_the_subject_from_git
    run_in_project("abc1234", "completed")

    assert_equal "Add retry", @reports.for("abc1234", "fast").subject
  end

  def test_should_name_the_newer_commit_of_a_cancelled_run
    cancelled = run_in_project("abc1234", "cancelled")
    run_in_project("bcd2345", "running")

    assert_equal "bcd2345", @reports.for("abc1234", "fast").superseded_by, "run #{cancelled}"
  end

  def test_should_name_no_newer_commit_for_a_run_that_was_not_cancelled
    run_in_project("abc1234", "completed")
    run_in_project("bcd2345", "running")

    assert_nil @reports.for("abc1234", "fast").superseded_by
  end

  private

  def record_trunk_check(sha, merge)
    FunCi::Persistence::TrunkChecks.new(@db, "/project").record(trunk_check(sha, merge, seen_at: @clock.now),
                                                                checked_at: @clock.now)
  end

  def run_in_project(sha, status)
    run_id = FunCi::Persistence::PipelineRun.create(@db, commit_hash: sha, branch: "main", project_path: "/project")
    record_stages(run_id, status == "failed" ? "failed" : "completed") unless status == "running"
    FunCi::Persistence::PipelineRun.update_status(@db, run_id, status)
    run_id
  end

  def record_stages(run_id, outcome)
    %w[lint build fast].each { |stage| create_stage_job(run_id, stage, "running", outcome) }
  end
end
