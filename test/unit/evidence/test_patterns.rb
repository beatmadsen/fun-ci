# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/evidence/patterns"

# A project's or a preset's patterns run on output fun-ci doesn't control, so
# each match is bounded, whatever a pattern backtracks into.
class TestPatterns < Minitest::Test
  PATTERNS = FunCi::Evidence::Patterns

  def test_should_give_each_pattern_a_timeout_of_a_second
    assert_equal [1.0, 1.0], PATTERNS.compile(%w[ERROR FAIL]).map(&:timeout)
  end

  # Ruby 3.2 and later memoise the classic ^(a+)+$, which then never times
  # out; the back-reference keeps this one backtracking on every Ruby in CI,
  # for a quarter of a second, so it ends even without the timeout.
  def test_should_stop_a_match_that_runs_past_its_timeout
    pattern = PATTERNS.compile(['^(a+)+\1$'], timeout: 0.01).first

    assert_raises(Regexp::TimeoutError) { pattern.match?("#{"a" * 24}!") }
  end

  def test_should_say_why_a_pattern_does_not_compile
    assert_equal "has '(', which doesn't compile: end pattern with unmatched parenthesis: /(/", PATTERNS.mistake("(")
  end

  def test_should_find_nothing_wrong_with_a_pattern_that_compiles
    assert_nil PATTERNS.mistake("ERROR")
  end
end
