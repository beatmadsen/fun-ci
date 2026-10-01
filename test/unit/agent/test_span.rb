# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/agent/span"

# How long a job's run took, in the console's words (acceptance-tests.md, AT-13.21, AT-13.22).
class TestSpan < Minitest::Test
  def test_should_count_a_short_run_in_seconds
    assert_equal "42s", FunCi::Agent::Span.words(42.4)
  end

  def test_should_count_a_run_under_an_hour_in_minutes
    assert_equal "50m", FunCi::Agent::Span.words(3000)
  end

  def test_should_count_a_run_of_whole_hours_in_hours
    assert_equal "2h", FunCi::Agent::Span.words(7200)
  end

  def test_should_count_a_run_of_hours_in_hours_and_minutes
    assert_equal "3h12m", FunCi::Agent::Span.words(11_520)
  end

  def test_should_count_a_run_of_whole_days_in_days
    assert_equal "1d", FunCi::Agent::Span.words(86_400)
  end

  def test_should_count_a_run_of_days_in_days_and_hours
    assert_equal "1d2h", FunCi::Agent::Span.words(93_600)
  end
end
