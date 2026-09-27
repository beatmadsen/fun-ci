# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/agent/age"

class TestAge < Minitest::Test
  AGE = FunCi::Agent::Age

  def test_should_call_under_a_minute_just_now
    assert_equal "just now", AGE.words(59)
  end

  def test_should_count_whole_minutes_under_an_hour
    assert_equal ["1m ago", "59m ago"], [AGE.words(60), AGE.words(3599)]
  end

  def test_should_count_whole_hours_under_a_day
    assert_equal ["1h ago", "23h ago"], [AGE.words(3600), AGE.words(86_399)]
  end

  def test_should_count_whole_days_after_that
    assert_equal "2d ago", AGE.words((2 * 86_400) + 5)
  end
end
