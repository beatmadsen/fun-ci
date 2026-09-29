# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/agent/trunk_text"

# The trunk line `status` and `wait` print (docs/trunk-conflicts.md, status and wait).
class TestTrunkText < Minitest::Test
  NOW = Time.utc(2026, 9, 29, 10, 0, 0)
  TRUNK_SHA = "9e1d004aaaabbbbccccddddeeeeffff000011112"

  def test_should_name_the_trunk_its_age_and_the_counts_for_a_clean_merge
    assert_equal ["  trunk  clean        origin/main 9e1d004, fetched 2m ago, 3 ahead, 4 behind"],
                 lines(outcome: "clean", ahead: 3, behind: 4)
  end

  def test_should_list_the_conflicting_files_under_the_line
    assert_equal ["    lib/cart.rb", "    lib/total.rb"],
                 lines(outcome: "conflicts", ahead: 3, behind: 4, files: ["lib/cart.rb", "lib/total.rb"]).drop(1)
  end

  def test_should_leave_out_the_counts_when_up_to_date
    assert_equal ["  trunk  up to date   origin/main 9e1d004, fetched 2m ago"],
                 lines(outcome: "clean", ahead: 3, behind: 0)
  end

  def test_should_say_only_in_trunk_when_the_trunk_has_the_commit
    assert_equal ["  trunk  in trunk"], lines(outcome: "clean", ahead: 0, behind: 4)
  end

  def test_should_give_the_reason_when_unknown
    assert_equal ["  trunk  unknown      no trunk found; set trunk: in .fun-ci/config"],
                 lines(outcome: "unknown", reason: "no trunk found; set trunk: in .fun-ci/config")
  end

  private

  def lines(**fields)
    check = FunCi::Trunk::Check.new(commit: "abc", ref: "origin/main", trunk_sha: TRUNK_SHA, seen_at: NOW - 120,
                                    **fields)
    FunCi::Agent::TrunkText.lines(FunCi::Trunk::Shown.of(check, now: NOW))
  end
end
