# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/trunk/merge_check"

# What merging a commit with a trunk tip would do, from git's answers
# (docs/trunk-conflicts.md, How the check works).
class TestMergeCheck < Minitest::Test
  MERGE = FunCi::Trunk::Merge
  Answer = FunCi::Trunk::MergeCheck::Answer

  # Answers the counts and the merge it was given, and says whether a merge was asked for.
  class FakeGit
    attr_reader :merged, :version

    # counts: [ahead, behind], or the Answer of a git that failed to count.
    def initialize(counts:, merge: nil, version: "2.53.0")
      @counts = counts.is_a?(Array) ? Answer.new(0, "#{counts.join("\t")}\n", "") : counts
      @merge = merge
      @version = version
      @merged = false
    end

    def counts(_commit, _trunk) = @counts

    def merge_tree(_commit, _trunk)
      @merged = true
      @merge
    end
  end

  def test_should_not_merge_a_commit_the_trunk_already_has
    git = FakeGit.new(counts: [0, 4])
    check(git)

    refute git.merged
  end

  def test_should_find_nothing_to_merge_when_the_commit_is_not_behind
    assert_equal MERGE.clean(ahead: 3, behind: 0), check(FakeGit.new(counts: [3, 0]))
  end

  def test_should_find_a_clean_merge_when_git_merges_without_conflicts
    assert_equal MERGE.clean(ahead: 3, behind: 4),
                 check(FakeGit.new(counts: [3, 4], merge: Answer.new(0, "tree\n", "")))
  end

  def test_should_name_the_conflicting_files
    output = "tree\nlib/cart.rb\nlib/total.rb\n\nAuto-merging lib/cart.rb\nCONFLICT (content): in lib/cart.rb\n"

    assert_equal MERGE.conflicts(%w[lib/cart.rb lib/total.rb], ahead: 3, behind: 4),
                 check(FakeGit.new(counts: [3, 4], merge: Answer.new(1, output, "")))
  end

  def test_should_say_a_trunk_with_no_history_in_common_needs_setting
    answer = Answer.new(128, "", "fatal: refusing to merge unrelated histories\n")

    assert_equal MERGE.unknown("origin/main shares no history with this commit; set trunk: in .fun-ci/config"),
                 check(FakeGit.new(counts: [3, 4], merge: answer))
  end

  def test_should_name_the_git_needed_when_merge_tree_cannot_write_a_tree
    answer = Answer.new(129, "", "error: unknown option `write-tree'\n")

    assert_equal MERGE.unknown("needs git 2.38 or later; this is 2.34.1"),
                 check(FakeGit.new(counts: [3, 4], merge: answer, version: "2.34.1"))
  end

  def test_should_give_git_s_first_line_for_any_other_failure
    answer = Answer.new(128, "", "fatal: bad object abc\nmore\n")

    assert_equal MERGE.unknown("git merge-tree: fatal: bad object abc"),
                 check(FakeGit.new(counts: [3, 4], merge: answer))
  end

  def test_should_give_git_s_reason_when_it_cannot_count
    assert_equal MERGE.unknown("git rev-list: fatal: bad revision"),
                 check(FakeGit.new(counts: Answer.new(128, "", "fatal: bad revision\n")))
  end

  private

  def check(git) = FunCi::Trunk::MergeCheck.new(git).merge("abc1234", "fff0000", "origin/main")
end
