# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/trunk_kit"
require "fun_ci/agent/trunk_verdict"
require "fun_ci/trunk/shown"

# What a run means for an agent that asks with --trunk (docs/trunk-conflicts.md, status and wait).
class TestTrunkVerdict < Minitest::Test
  include TrunkKit

  NOW = Time.utc(2026, 9, 29, 10)
  CONFLICTS = MERGE.conflicts(["a.rb"], ahead: 1, behind: 1)

  def test_should_find_a_passed_run_that_conflicts_in_conflict
    assert_equal :conflicts, judge(:passed, shown(CONFLICTS))
  end

  def test_should_keep_a_failure_whatever_the_trunk_says
    assert_equal :failed, judge(:failed, shown(CONFLICTS))
  end

  def test_should_keep_a_passed_run_passed_when_the_trunk_is_unknown
    assert_equal :passed, judge(:passed, shown(MERGE.unknown("no trunk")))
  end

  def test_should_leave_a_passed_run_undecided_while_its_check_is_going
    assert_equal :undecided, judge(:passed, FunCi::Trunk::Shown.unchecked(started: NOW, now: NOW))
  end

  def test_should_keep_a_passed_run_passed_when_it_began_no_check
    assert_equal :passed, judge(:passed, nil)
  end

  private

  def shown(merge) = FunCi::Trunk::Shown.of(trunk_check("abc", merge, seen_at: NOW), now: NOW)
  def judge(verdict, shown) = FunCi::Agent::TrunkVerdict.of(verdict, shown)
end
