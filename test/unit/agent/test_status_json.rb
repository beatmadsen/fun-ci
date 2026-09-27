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

  private

  def document(verdict: :undecided, superseded_by: nil)
    report = REPORT.new(sha: "3f9c2ab0c4d1", subject: "Add retry", branch: "main", need: "fast",
                        stages: [STAGE.new(name: "lint", state: "passed", seconds: 3.8)], verdict: verdict,
                        superseded_by: superseded_by)
    FunCi::Agent::StatusJson.document(report)
  end
end
