# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/trunk/checker"

# A commit checked against the trunk the project names or has (docs/trunk-conflicts.md).
class TestTrunkChecker < Minitest::Test
  MERGE = FunCi::Trunk::Merge
  ANSWER = FunCi::Trunk::MergeCheck::Answer
  MOVED = Time.utc(2026, 9, 29, 9)
  Config = Data.define(:trunk)

  # A repository with origin/main at fff0000, which the commit is up to date with.
  class FakeGit
    def refs = FunCi::Trunk::Refs.new(remotes: ["origin"], branches: ["origin/main"], heads: { "origin" => "main" })
    def rev(ref) = ref == "refs/remotes/origin/main" ? "fff0000" : nil
    def moved_at(_ref) = MOVED
    def counts(_commit, _trunk) = ANSWER.new(status: 0, out: "2\t0\n", err: "")
  end

  def test_should_check_the_commit_against_the_tip_of_the_trunk
    assert_equal FunCi::Trunk::Tip.new(remote: "origin", branch: "main", sha: "fff0000", seen_at: MOVED),
                 check(nil).tip
  end

  def test_should_find_how_the_commit_would_merge_with_that_tip
    assert_equal MERGE.clean(ahead: 2, behind: 0), check(nil).merge
  end

  def test_should_make_no_check_when_the_project_says_none
    assert_nil check("none")
  end

  def test_should_say_the_named_trunk_does_not_exist
    assert_equal MERGE.unknown("origin/develop doesn't exist; set trunk: in .fun-ci/config"),
                 check("origin/develop").merge
  end

  def test_should_say_no_trunk_was_found
    git = FakeGit.new
    def git.refs = FunCi::Trunk::Refs.new(remotes: [], branches: ["feat/x"], heads: {})

    assert_equal MERGE.unknown("no trunk found; set trunk: in .fun-ci/config"),
                 FunCi::Trunk::Checker.new(git, Config.new(trunk: nil)).check("abc1234").merge
  end

  private

  def check(setting) = FunCi::Trunk::Checker.new(FakeGit.new, Config.new(trunk: setting)).check("abc1234")
end
