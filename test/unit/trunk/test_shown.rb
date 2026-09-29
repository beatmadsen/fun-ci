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

  private

  def shown(merge) = FunCi::Trunk::Shown.of(trunk_check("abc", merge, seen_at: NOW - 120), now: NOW)
end
