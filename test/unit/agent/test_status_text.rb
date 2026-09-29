# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/agent/status_text"
require_relative "../../support/trunk_kit"

class TestStatusText < Minitest::Test
  include TrunkKit

  REPORT = FunCi::Agent::RunReport
  STAGE = REPORT::Stage

  def test_should_start_with_the_short_sha_the_subject_and_the_branch
    assert_equal %(fun-ci: 3f9c2ab "Add retry" on main), lines.first
  end

  def test_should_give_a_finished_stage_its_state_and_duration
    assert_equal "  lint   passed         3.8s", lines[1]
  end

  def test_should_shout_a_stage_that_failed
    assert_equal "  build  FAILED        12.0s", lines(build: stage("build", "failed", 12.0))[2]
  end

  def test_should_shout_a_stage_that_ran_over_budget
    assert_includes lines(build: stage("build", "over_budget", 30.0))[2], "OVER BUDGET"
  end

  def test_should_mark_a_stage_the_level_does_not_need
    assert_equal "  slow   running             (not needed)", lines[4]
  end

  def test_should_name_the_commit_that_superseded_the_run
    assert_equal "Superseded by bcd2345.", lines(verdict: :superseded, superseded_by: "bcd2345aaaa").last
  end

  def test_should_name_no_newer_commit_unless_the_run_was_superseded
    refute_includes lines(verdict: :passed, superseded_by: "bcd2345aaaa").last, "Superseded"
  end

  def test_should_print_the_trunk_line_after_the_stages_when_the_run_was_checked
    assert_equal "  trunk  in trunk", lines(trunk: in_trunk)[5]
  end

  def test_should_say_the_check_is_going_when_asked_about_the_trunk
    checking = FunCi::Trunk::Shown.unchecked(started: Time.utc(2026, 9, 29), now: Time.utc(2026, 9, 29))
    report = REPORT.new(sha: "3f9c2ab0c4d1", subject: "s", branch: "main", need: "fast", stages: [],
                        verdict: :undecided, superseded_by: nil, trunk: checking)

    assert_equal "  trunk  checking", FunCi::Agent::StatusText.lines(report, trunk: true).last
  end

  def test_should_print_no_trunk_line_while_the_check_is_going
    checking = FunCi::Trunk::Shown.unchecked(started: Time.utc(2026, 9, 29), now: Time.utc(2026, 9, 29))

    refute_includes lines(trunk: checking).join("\n"), "trunk"
  end

  def test_should_not_say_how_to_integrate_while_a_needed_stage_has_failed
    refute_includes lines(verdict: :failed, trunk: conflict, deciding: "build").join("\n"), "integrate"
  end

  private

  def conflict
    now = Time.utc(2026, 9, 29)
    merge = MERGE.conflicts(["a.rb"], ahead: 1, behind: 1)
    FunCi::Trunk::Shown.of(trunk_check("3f9c2ab", merge, seen_at: now), now: now)
  end

  def in_trunk
    now = Time.utc(2026, 9, 29)
    FunCi::Trunk::Shown.of(trunk_check("3f9c2ab", MERGE.clean(ahead: 0, behind: 2), seen_at: now), now: now)
  end

  def stage(name, state, seconds = nil) = STAGE.new(name: name, state: state, seconds: seconds)

  # fields: the report's superseded_by, deciding and trunk, each nil unless given.
  def lines(verdict: :undecided, build: stage("build", "passed", 11.2), **fields)
    stages = [stage("lint", "passed", 3.8), build,
              stage("fast", "running"), stage("slow", "running")]
    report = REPORT.new(sha: "3f9c2ab0c4d1", subject: "Add retry", branch: "main", need: "fast", stages: stages,
                        verdict: verdict, superseded_by: nil, **fields)
    FunCi::Agent::StatusText.lines(report)
  end
end
