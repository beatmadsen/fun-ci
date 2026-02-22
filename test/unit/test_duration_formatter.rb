# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/duration_formatter"

class TestDurationFormatter < Minitest::Test
  def test_should_format_sub_second_durations_with_decimal
    # Given a duration of 0.3 seconds
    result = FunCi::Tui::DurationFormatter.format(0.3)
    # Then it should show "0.3s"
    assert_equal "0.3s", result
  end

  def test_should_format_seconds_with_one_decimal
    # Given a duration of 1.8 seconds
    result = FunCi::Tui::DurationFormatter.format(1.8)
    # Then it should show "1.8s"
    assert_equal "1.8s", result
  end

  def test_should_format_whole_seconds_without_decimal
    # Given a duration of 47 seconds
    result = FunCi::Tui::DurationFormatter.format(47.0)
    # Then it should show "47s"
    assert_equal "47s", result
  end

  def test_should_format_minutes_and_seconds
    # Given a duration of 62 seconds (1m02)
    result = FunCi::Tui::DurationFormatter.format(62.0)
    # Then it should show "1m02"
    assert_equal "1m02", result
  end

  def test_should_format_longer_minutes
    # Given a duration of 3 minutes 1 second
    result = FunCi::Tui::DurationFormatter.format(181.0)
    # Then it should show "3m01"
    assert_equal "3m01", result
  end

  def test_should_format_exactly_60_seconds_as_1m00
    # Given a duration of exactly 60 seconds
    result = FunCi::Tui::DurationFormatter.format(60.0)
    # Then it should show "1m00"
    assert_equal "1m00", result
  end

  def test_should_format_6_point_2_seconds
    # Given a duration of 6.2 seconds
    result = FunCi::Tui::DurationFormatter.format(6.2)
    # Then it should show "6.2s"
    assert_equal "6.2s", result
  end
end
