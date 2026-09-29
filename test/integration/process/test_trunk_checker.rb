# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/trunk_repos"
require "fun_ci/trunk/checker"

# A commit checked against the trunk in real repositories (docs/trunk-conflicts.md, AT-11.1, AT-11.2).
class TestTrunkChecker < Minitest::Test
  def setup = @repos = TrunkRepos.create
  def teardown = @repos.remove

  def test_should_find_a_clean_merge_when_both_sides_changed_different_lines
    @repos.upstream("shared.txt" => "ONE\ntwo\nthree\n")
    sha = @repos.work("shared.txt" => "one\ntwo\nTHREE\n")
    @repos.git(@repos.project, "fetch", "-q")

    assert_equal FunCi::Trunk::Merge.clean(ahead: 1, behind: 1), check(sha).merge
  end

  def test_should_find_the_conflicting_files_when_both_sides_changed_the_same_lines
    @repos.upstream("shared.txt" => "one\nTWO\nthree\n")
    sha = @repos.work("shared.txt" => "one\n2\nthree\n")
    @repos.git(@repos.project, "fetch", "-q")

    assert_equal FunCi::Trunk::Merge.conflicts(["shared.txt"], ahead: 1, behind: 1), check(sha).merge
  end

  private

  def check(sha) = FunCi::Trunk::Checker.for(@repos.project).check(sha)
end
