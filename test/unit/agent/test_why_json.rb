# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/agent/why_json"

# `fun-ci why --json` (acceptance-tests.md, AT-10.2; the document is why.md's).
class TestWhyJson < Minitest::Test
  REPORT = FunCi::Agent::RunReport
  EXIT = REPORT::Exit.new(exit_status: 1, signal: nil, budget: 10)

  def test_should_give_the_commit
    assert_equal({ sha: "3f9c2ab0c4d1", branch: "main", subject: "Add retry" }, document(stage("failed"))[:commit])
  end

  def test_should_give_the_stage_as_the_status_document_names_it
    assert_equal({ stage: "fast", state: "over_budget", exit_status: 1, signal: nil, seconds: 8.4, budget: 10 },
                 document(stage("over_budget")).slice(:stage, :state, :exit_status, :signal, :seconds, :budget))
  end

  def test_should_give_the_evidence_of_a_stage_that_failed
    assert_equal %i[chosen facts failures excerpts problems], document(stage("failed"))[:evidence].keys
  end

  def test_should_say_there_is_no_evidence_for_a_stage_that_failed_with_some
    assert_nil document(stage("failed"))[:no_evidence]
  end

  def test_should_say_why_there_is_no_evidence_for_a_stage_that_did_not_fail
    assert_equal [nil, "running"], document(stage("running")).values_at(:evidence, :no_evidence)
  end

  def test_should_say_why_there_is_no_evidence_when_no_stage_decided
    assert_equal [nil, nil, "passed"], document(nil, verdict: :passed).values_at(:stage, :evidence, :no_evidence)
  end

  private

  def stage(state) = REPORT::Stage.new(name: "fast", state: state, seconds: 8.4, exit: EXIT)

  def document(stage, verdict: :failed)
    report = REPORT.new(sha: "3f9c2ab0c4d1", subject: "Add retry", branch: "main", need: "fast", stages: [stage],
                        verdict: verdict, superseded_by: nil)
    FunCi::Agent::WhyJson.document(report, stage)
  end
end
