# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/trunk_repos"
require "fun_ci/trunk/git"

# The git the trunk check asks, against real repositories.
class TestTrunkGit < Minitest::Test
  def setup
    @repos = TrunkRepos.create
    @git = FunCi::Trunk::Git.new(@repos.project)
  end

  def teardown = @repos.remove

  def conflicting
    @repos.upstream("shared.txt" => "one\nTWO\nthree\n")
    sha = @repos.work("shared.txt" => "one\n2\nthree\n")
    @repos.git(@repos.project, "fetch", "-q")
    sha
  end

  def test_should_count_the_commits_each_side_has_that_the_other_lacks
    @repos.upstream("a.txt" => "a\n")
    sha = @repos.work("b.txt" => "b\n")
    @repos.git(@repos.project, "fetch", "-q")

    assert_equal "1\t1\n", @git.counts(sha, "refs/remotes/origin/main").out
  end

  def test_should_list_the_remotes_branches_and_default_branches
    @repos.work("b.txt" => "b\n")

    assert_equal FunCi::Trunk::Refs.new(remotes: ["origin"], branches: %w[feat/cart main origin/main],
                                        heads: { "origin" => "main" }), @git.refs
  end

  def test_should_leave_no_object_behind_when_merging
    @repos.upstream("shared.txt" => "one\nTWO\nthree\n")
    sha = @repos.work("shared.txt" => "one\n2\nthree\n")
    @repos.git(@repos.project, "fetch", "-q")
    before = @repos.git(@repos.project, "count-objects")
    @git.merge_tree(sha, "refs/remotes/origin/main")

    assert_equal before, @repos.git(@repos.project, "count-objects")
  end

  def test_should_give_git_s_messages_about_a_conflict
    sha = conflicting

    assert_includes @git.explain(sha, "refs/remotes/origin/main").messages,
                    "CONFLICT (content): Merge conflict in shared.txt"
  end

  def test_should_give_each_conflicted_file_as_the_merge_leaves_it
    sha = conflicting

    assert_match(/<<<<<<< .*\n2\n=======\nTWO\n>>>>>>> /,
                 @git.explain(sha, "refs/remotes/origin/main").files["shared.txt"])
  end

  def test_should_leave_no_object_behind_when_explaining
    sha = conflicting
    before = @repos.git(@repos.project, "count-objects")
    @git.explain(sha, "refs/remotes/origin/main")

    assert_equal before, @repos.git(@repos.project, "count-objects")
  end

  def test_should_stop_a_merge_that_runs_over_its_budget
    sha = conflicting
    git = FunCi::Trunk::Git.new(@repos.project, timer: ->(*) { false })

    assert_equal FunCi::Trunk::MergeCheck::OVER_BUDGET, git.merge_tree(sha, "refs/remotes/origin/main")
  end

  def test_should_name_no_top_directory_outside_a_repository
    assert_nil FunCi::Trunk::Git.new(File.join(@repos.project, "..")).toplevel
  end

  def test_should_answer_the_sha_a_ref_names
    assert_equal @repos.git(@repos.project, "rev-parse", "origin/main").strip, @git.rev("refs/remotes/origin/main")
  end

  def test_should_answer_nothing_for_a_ref_that_does_not_exist
    assert_nil @git.rev("refs/remotes/origin/nosuch")
  end

  def test_should_say_when_a_ref_last_moved
    assert_in_delta Time.now, @git.moved_at("refs/remotes/origin/main"), 60
  end
end
