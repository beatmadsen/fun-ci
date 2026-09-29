# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/agent/reports"
require_relative "../support/fake_git"
require_relative "../support/fake_clock"
require "fun_ci/persistence/trunk_checks"
require_relative "../support/trunk_kit"

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
    @reports = FunCi::Agent::Reports.new(@db, git, @clock)
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
