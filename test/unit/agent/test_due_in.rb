# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/agent/due_in"

# When a job is due again, in words, rounded up as the console rounds it (acceptance-tests.md, AT-13.22).
class TestDueIn < Minitest::Test
  def test_should_say_a_minute_for_less_than_one
    assert_equal "1m", FunCi::Agent::DueIn.words(5)
  end

  def test_should_round_minutes_up
    assert_equal "46m", FunCi::Agent::DueIn.words((45 * 60) + 1)
  end

  def test_should_say_an_hour_for_an_hour_less_a_few_seconds
    assert_equal "1h", FunCi::Agent::DueIn.words(3595)
  end

  def test_should_round_hours_up
    assert_equal "3h", FunCi::Agent::DueIn.words((2 * 3600) + 1)
  end

  def test_should_say_a_day_for_a_day_less_a_few_seconds
    assert_equal "1d", FunCi::Agent::DueIn.words(86_395)
  end

  def test_should_round_days_up
    assert_equal "7d", FunCi::Agent::DueIn.words(601_200)
  end
end
