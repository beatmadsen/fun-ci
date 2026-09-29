# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/trunk/shown"

# What a run's check against the trunk is shown as (docs/trunk-conflicts.md, What it answers).
class TestTrunkShown < Minitest::Test
  NOW = Time.utc(2026, 9, 29, 10, 0, 0)

  def test_should_show_the_outcome_when_both_sides_have_moved_on
    assert_equal "conflicts", shown(outcome: "conflicts", ahead: 3, behind: 4).state
  end

  def test_should_show_in_trunk_when_the_commit_is_not_ahead
    assert_equal "in_trunk", shown(outcome: "clean", ahead: 0, behind: 4).state
  end

  def test_should_show_up_to_date_when_the_commit_is_not_behind
    assert_equal "up_to_date", shown(outcome: "clean", ahead: 3, behind: 0).state
  end

  def test_should_show_unknown_when_the_check_could_not_be_made
    assert_equal "unknown", shown(outcome: "unknown", reason: "no trunk").state
  end

  def test_should_say_how_long_ago_the_trunk_was_seen
    assert_equal 120, shown(outcome: "clean", ahead: 1, behind: 1).age
  end

  private

  def shown(**fields)
    check = FunCi::Trunk::Check.new(commit: "abc", ref: "origin/main", trunk_sha: "fff", seen_at: NOW - 120, **fields)
    FunCi::Trunk::Shown.of(check, now: NOW)
  end
end
