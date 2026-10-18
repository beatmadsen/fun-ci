# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/trunk_repos"
require "fun_ci/trunk/git"

# A merge check past its budget is stopped. Apart from test_trunk_git.rb, which
# never reaches the kill: mutineer runs every file that covers a mutant's line
# within one 10 s cap, and the kill's pure code (ProcessTree, GroupKill) must
# not wait on that file's real merges.
class TestTrunkGitBudget < Minitest::Test
  def setup = @repos = TrunkRepos.create
  def teardown = @repos.remove

  def test_should_stop_a_merge_that_runs_over_its_budget
    @repos.upstream("shared.txt" => "one\nTWO\nthree\n")
    sha = @repos.work("shared.txt" => "one\n2\nthree\n")
    @repos.git(@repos.project, "fetch", "-q")
    git = FunCi::Trunk::Git.new(@repos.project, timer: ->(*) { false })

    assert_equal FunCi::Trunk::MergeCheck::OVER_BUDGET, git.merge_tree(sha, "refs/remotes/origin/main")
  end
end
