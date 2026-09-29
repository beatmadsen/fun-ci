# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/trunk_kit"
require "fun_ci/trunk/shown"

# What a run's check against the trunk is shown as (docs/trunk-conflicts.md, What it answers).
class TestTrunkShown < Minitest::Test
  include TrunkKit

  NOW = Time.utc(2026, 9, 29, 10, 0, 0)

  def test_should_show_the_outcome_when_both_sides_have_moved_on
    assert_equal "conflicts", shown(MERGE.conflicts(["a.rb"], ahead: 3, behind: 4)).state
  end

  def test_should_show_in_trunk_when_the_commit_is_not_ahead
    assert_equal "in_trunk", shown(MERGE.clean(ahead: 0, behind: 4)).state
  end

  def test_should_show_up_to_date_when_the_commit_is_not_behind
    assert_equal "up_to_date", shown(MERGE.clean(ahead: 3, behind: 0)).state
  end

  def test_should_show_unknown_when_the_check_could_not_be_made
    assert_equal "unknown", shown(MERGE.unknown("no trunk")).state
  end

  def test_should_say_how_long_ago_the_trunk_was_seen
    assert_equal 120, shown(MERGE.clean(ahead: 1, behind: 1)).age
  end

  def test_should_show_a_check_without_a_tip_as_unknown
    check = FunCi::Trunk::Check.new(commit: "abc", tip: nil, merge: MERGE.unknown("no trunk"))

    assert_equal "unknown", FunCi::Trunk::Shown.of(check, now: NOW).state
  end

  def test_should_show_a_check_still_within_its_time_as_checking
    assert_equal "checking", FunCi::Trunk::Shown.unchecked(started: NOW - 24, now: NOW).state
  end

  def test_should_show_a_check_past_its_time_as_unknown
    assert_equal MERGE.unknown("the check never finished"),
                 FunCi::Trunk::Shown.unchecked(started: NOW - 26, now: NOW).check.merge
  end

  def test_should_count_a_trunk_seen_over_an_hour_ago_as_stale
    assert_predicate shown_seen(NOW - 3601), :stale?
  end

  def test_should_count_a_trunk_seen_within_the_hour_as_fresh
    refute_predicate shown_seen(NOW - 3600), :stale?
  end

  def test_should_count_a_trunk_whose_last_fetch_failed_as_stale
    assert_predicate shown_after_fetch("fatal: no route"), :stale?
  end

  def test_should_keep_why_the_last_fetch_failed
    assert_equal "fatal: no route", shown_after_fetch("fatal: no route").fetch_error
  end

  private

  def shown_seen(at)
    FunCi::Trunk::Shown.of(trunk_check("abc", MERGE.clean(ahead: 1, behind: 1), seen_at: at), now: NOW)
  end

  def shown_after_fetch(error)
    check = trunk_check("abc", MERGE.clean(ahead: 1, behind: 1), seen_at: NOW)
    FunCi::Trunk::Shown.of(check, now: NOW, fetch: FunCi::Trunk::LastFetch.new(fetched_at: nil, error: error))
  end

  def shown(merge) = FunCi::Trunk::Shown.of(trunk_check("abc", merge, seen_at: NOW - 120), now: NOW)
end
