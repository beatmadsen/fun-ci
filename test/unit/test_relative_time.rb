# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/relative_time"

class TestRelativeTime < Minitest::Test
  def test_should_show_just_now_for_recent_times
    # Given a timestamp from 5 seconds ago
    now = Time.now
    timestamp = (now - 5).utc.iso8601
    # When we format it
    result = FunCi::Tui::RelativeTime.format(timestamp, now: now)
    # Then it should say "just now"
    assert_equal "just now", result, "Times under 60 seconds should show 'just now'"
  end

  def test_should_show_minutes_ago
    # Given a timestamp from 2 minutes ago
    now = Time.now
    timestamp = (now - 120).utc.iso8601
    # When we format it
    result = FunCi::Tui::RelativeTime.format(timestamp, now: now)
    # Then it should say "2m ago"
    assert_equal "2m ago", result, "Should show minutes for times between 1-59 minutes"
  end

  def test_should_show_hours_ago
    # Given a timestamp from 3 hours ago
    now = Time.now
    timestamp = (now - 3 * 3600).utc.iso8601
    # When we format it
    result = FunCi::Tui::RelativeTime.format(timestamp, now: now)
    # Then it should say "3h ago"
    assert_equal "3h ago", result, "Should show hours for times over 60 minutes"
  end

  def test_should_show_1m_ago_at_exactly_60_seconds
    # Given a timestamp from exactly 60 seconds ago
    now = Time.now
    timestamp = (now - 60).utc.iso8601
    # When we format it
    result = FunCi::Tui::RelativeTime.format(timestamp, now: now)
    # Then it should say "1m ago"
    assert_equal "1m ago", result, "60 seconds should round to 1m ago"
  end

  def test_should_show_1h_ago_at_exactly_60_minutes
    # Given a timestamp from exactly 60 minutes ago
    now = Time.now
    timestamp = (now - 3600).utc.iso8601
    # When we format it
    result = FunCi::Tui::RelativeTime.format(timestamp, now: now)
    # Then it should say "1h ago", result
    assert_equal "1h ago", result, "60 minutes should round to 1h ago"
  end
end
