# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/evidence/deadline"

# When the evidence budget runs out, read from a clock.
class TestDeadline < Minitest::Test
  def test_should_have_passed_once_the_clock_reaches_it
    assert_predicate deadline(now: 12), :passed?
  end

  def test_should_not_have_passed_before_the_clock_reaches_it
    refute_predicate deadline(now: 11.9), :passed?
  end

  def test_should_say_how_long_is_left
    assert_in_delta 0.5, deadline(now: 11.5).left
  end

  def test_should_say_no_time_is_left_once_it_has_passed
    assert_equal 0, deadline(now: 13).left
  end

  private

  # Two seconds from 10, read at `now`.
  def deadline(now:)
    times = [10, now]
    FunCi::Evidence::Deadline.after(-> { times.shift || now }, 2)
  end
end
