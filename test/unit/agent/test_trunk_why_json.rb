# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/agent/trunk_why_json"

# `why REV trunk --json` (design.md, The trunk).
class TestTrunkWhyJson < Minitest::Test
  REPORT = FunCi::Agent::RunReport
  EXCERPT = { title: "a.rb", location: "lines 1-9", lines: ["x"], extractor: "merge-tree" }.freeze

  def test_should_name_trunk_as_what_it_explains
    assert_equal "trunk", document(evidence([EXCERPT]))[:stage]
  end

  def test_should_carry_the_evidence
    assert_equal [EXCERPT], document(evidence([EXCERPT]))[:evidence][:excerpts]
  end

  def test_should_cut_the_evidence_to_what_an_agent_s_context_takes
    long = EXCERPT.merge(lines: Array.new(4000) { "x" * 100 })

    assert document(evidence([long]))[:evidence][:excerpts].first[:truncated]
  end

  def test_should_say_why_there_is_nothing_to_explain
    assert_equal "no conflict", document(nil)[:no_evidence]
  end

  private

  def evidence(excerpts)
    FunCi::Evidence::Document.new(chosen: [], facts: [], failures: [], excerpts: excerpts,
                                  problems: [])
  end

  def document(evidence)
    report = REPORT.new(sha: "3f9c2ab", subject: "s", branch: "main", need: "fast", stages: [], verdict: :passed,
                        superseded_by: nil)
    FunCi::Agent::TrunkWhyJson.document(report, evidence)
  end
end
