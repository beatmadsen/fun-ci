# frozen_string_literal: true

require_relative "../../test_helper"
require "json"
require "fun_ci/evidence/caps"
require "fun_ci/evidence/document"

# The evidence is printed whole into an agent's context, so it has a size
# (architecture.md, "Evidence of a failed stage").
class TestCaps < Minitest::Test
  CAPS = FunCi::Evidence::Caps
  LIMITS = CAPS::Limits.new(bytes: 1000, failures: 3, message_lines: 2)

  def test_should_leave_evidence_within_its_size_alone
    document = doc(excerpts: [excerpt("a", 5)])

    assert_equal document, capped(document)
  end

  def test_should_cut_the_last_excerpt_first
    capped = capped(doc(excerpts: [excerpt("first", 10), excerpt("last", 60)]))

    assert_equal [10, true], [capped.excerpts.first[:lines].size, capped.excerpts.last[:truncated]]
  end

  def test_should_keep_the_first_excerpt_whole_when_cutting_the_last_is_enough
    assert_nil capped(doc(excerpts: [excerpt("first", 10), excerpt("last", 60)])).excerpts.first[:truncated]
  end

  def test_should_cut_no_more_lines_than_it_must
    whole = excerpt("last", 60)
    cut = capped(doc(excerpts: [whole])).excerpts.first
    one_more = cut.merge(lines: whole[:lines].first(cut[:lines].size + 1))

    assert_operator JSON.generate(doc(excerpts: [one_more]).to_h).bytesize, :>, LIMITS.bytes
  end

  def test_should_cut_messages_to_their_first_lines_when_the_excerpts_are_not_enough
    long = { test: "t", message: (["m" * 30] * 40).join("\n") }

    failure = capped(doc(failures: [long])).failures.first

    assert_equal [2, true], [failure[:message].lines.size, failure[:truncated]]
  end

  def test_should_leave_a_message_as_long_as_its_limit_whole
    at_limit = { test: "t", message: "#{"m" * 600}\n#{"n" * 600}" }

    assert_nil capped(doc(failures: [at_limit])).failures.first[:truncated]
  end

  def test_should_keep_at_most_its_number_of_failures
    assert_equal 3, capped(doc(failures: Array.new(5) { |n| { test: "t#{n}", message: "m" } })).failures.size
  end

  def test_should_count_the_failures_it_left_out_in_a_fact
    assert_includes capped(doc(failures: Array.new(5) { |n| { test: "t#{n}", message: "m" } })).facts,
                    { name: "failures not kept", value: "2", extractor: "fun-ci" }
  end

  def test_should_never_cut_facts_or_problems
    problems = Array.new(40) { |n| { extractor: "x", message: "problem #{n} #{"p" * 30}" } }

    assert_equal problems, capped(doc(problems: problems)).problems
  end

  private

  def excerpt(title, lines) = { title: title, location: "output", lines: Array.new(lines) { "#{"x" * 30} line" } }

  def doc(**lists)
    FunCi::Evidence::Document.new(chosen: [], facts: [], failures: [], excerpts: [], problems: [], **lists)
  end

  def capped(document) = CAPS.new(LIMITS).apply(document)
end
