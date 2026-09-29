# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/trunk_kit"
require "fun_ci/agent/trunk_text"

# The trunk line `status` and `wait` print (docs/trunk-conflicts.md, status and wait).
class TestTrunkText < Minitest::Test
  include TrunkKit

  NOW = Time.utc(2026, 9, 29, 10, 0, 0)
  CONFLICT = FunCi::Trunk::Merge.conflicts(["a.rb"], ahead: 1, behind: 1)

  def test_should_name_the_trunk_its_age_and_the_counts_for_a_clean_merge
    assert_equal ["  trunk  clean        origin/main 9e1d004, fetched 2m ago, 3 ahead, 4 behind"],
                 lines(MERGE.clean(ahead: 3, behind: 4))
  end

  def test_should_list_the_conflicting_files_under_the_line
    assert_equal ["    lib/cart.rb", "    lib/total.rb"],
                 lines(MERGE.conflicts(["lib/cart.rb", "lib/total.rb"], ahead: 3, behind: 4), next_step: false).drop(1)
  end

  def test_should_leave_out_the_counts_when_up_to_date
    assert_equal ["  trunk  up to date   origin/main 9e1d004, fetched 2m ago"], lines(MERGE.clean(ahead: 3, behind: 0))
  end

  def test_should_say_only_in_trunk_when_the_trunk_has_the_commit
    assert_equal ["  trunk  in trunk"], lines(MERGE.clean(ahead: 0, behind: 4))
  end

  def test_should_give_the_reason_when_unknown
    assert_equal ["  trunk  unknown      no trunk found; set trunk: in .fun-ci/config"],
                 lines(MERGE.unknown("no trunk found; set trunk: in .fun-ci/config"))
  end

  def test_should_say_what_to_do_after_the_files_of_a_conflict
    assert_match(%r{\AConflicts with origin/main in 1 file}, lines(CONFLICT).last)
  end

  def test_should_say_nothing_to_do_when_a_needed_stage_failed
    assert_equal "    a.rb", lines(CONFLICT, next_step: false).last
  end

  private

  def lines(merge, next_step: true)
    shown = FunCi::Trunk::Shown.of(trunk_check("abc", merge, seen_at: NOW - 120), now: NOW)
    FunCi::Agent::TrunkText.lines(shown, branch: "feat/cart", next_step: next_step)
  end
end
