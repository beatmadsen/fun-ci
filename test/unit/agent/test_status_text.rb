# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/agent/status_text"

class TestStatusText < Minitest::Test
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

  private

  def stage(name, state, seconds = nil) = STAGE.new(name: name, state: state, seconds: seconds)

  def lines(verdict: :undecided, superseded_by: nil, build: stage("build", "passed", 11.2))
    stages = [stage("lint", "passed", 3.8), build,
              stage("fast", "running"), stage("slow", "running")]
    report = REPORT.new(sha: "3f9c2ab0c4d1", subject: "Add retry", branch: "main", need: "fast", stages: stages,
                        verdict: verdict, superseded_by: superseded_by)
    FunCi::Agent::StatusText.lines(report)
  end
end
