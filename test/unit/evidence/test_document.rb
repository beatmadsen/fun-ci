# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/evidence/document"

# The evidence of a failed stage, as `fun-ci why` shows it.
class TestDocument < Minitest::Test
  DOCUMENT = FunCi::Evidence::Document

  def test_should_credit_a_stage_s_kept_failures_to_test_reports
    failure = { file: "a.rb", line: 3, test: "t", message: "m" }

    assert_equal [failure.merge(extractor: "test-reports")], DOCUMENT.legacy(tail: nil, failures: [failure]).failures
  end

  def test_should_make_a_stage_s_kept_tail_an_excerpt_of_output_tail
    assert_equal [{ title: "The output's last lines", location: "output", lines: %w[one two],
                    extractor: "output-tail" }],
                 DOCUMENT.legacy(tail: "one\ntwo\n", failures: []).excerpts
  end

  def test_should_have_no_excerpt_when_no_tail_was_kept
    assert_empty DOCUMENT.legacy(tail: nil, failures: []).excerpts
  end
end
