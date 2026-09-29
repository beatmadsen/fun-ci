# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/agent/status_json"

class TestStatusJson < Minitest::Test
  REPORT = FunCi::Agent::RunReport
  STAGE = REPORT::Stage

  def test_should_carry_the_schema_version
    assert_equal 1, document[:schema]
  end

  def test_should_describe_the_commit
    assert_equal({ sha: "3f9c2ab0c4d1", branch: "main", subject: "Add retry" }, document[:commit])
  end

  def test_should_name_the_verdict_for_the_level
    assert_equal %w[fast over_budget], document(verdict: :over_budget).values_at(:need, :verdict)
  end

  def test_should_give_each_stage_its_name_state_and_seconds
    assert_equal({ name: "lint", state: "passed", seconds: 3.8 }, document[:stages].first)
  end

  def test_should_name_the_commit_that_superseded_the_run
    assert_equal "bcd2345", document(superseded_by: "bcd2345")[:superseded_by]
  end

  def test_should_describe_a_commit_without_a_run
    assert_equal({ schema: 1, commit: { sha: "abc1234" }, verdict: "unknown" }, FunCi::Agent::StatusJson.unknown("abc1234"))
  end

  def test_should_list_a_stage_s_reported_failures
    failure = { file: "a.rb", line: 3, test: "t", message: "m" }
    stage = STAGE.new(name: "fast", state: "failed", seconds: 1.0,
                      kept: REPORT::Kept.new(tail: nil, failures: [failure]))

    assert_equal [failure], document(stages: [stage])[:stages].first[:failures]
  end

  def test_should_carry_the_trunk_the_run_was_checked_against
    now = Time.utc(2026, 9, 29)
    check = FunCi::Trunk::Check.new(commit: "3f9c2ab", tip: nil, merge: FunCi::Trunk::Merge.unknown("no trunk"))

    assert_equal "unknown", document(trunk: FunCi::Trunk::Shown.of(check, now: now))[:trunk][:state]
  end

  def test_should_carry_no_trunk_for_a_run_that_began_no_check
    assert_nil document.fetch(:trunk)
  end

  private

  # report: the report's superseded_by and trunk, each nil unless given.
  def document(verdict: :undecided, stages: [STAGE.new(name: "lint", state: "passed", seconds: 3.8)], **report)
    report = REPORT.new(sha: "3f9c2ab0c4d1", subject: "Add retry", branch: "main", need: "fast",
                        stages: stages, verdict: verdict, superseded_by: nil, **report)
    FunCi::Agent::StatusJson.document(report)
  end
end
