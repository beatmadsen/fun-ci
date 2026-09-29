# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/git_project"
require_relative "../../../script/mutation_lanes"

# What the nightly mutation workflow compares with: the files changed since
# its last finished run's commit, or nothing to compare with when git doesn't
# know that commit.
class TestMutationLanesGit < Minitest::Test
  def setup
    @project = GitProject.create
    @project.write("README.md", "first\n")
    @first = @project.commit("First")
  end

  def teardown = @project.remove

  def test_should_list_the_files_changed_since_a_commit
    @project.write("lib/cart.rb", "class Cart; end\n")
    @project.commit("Second")

    assert_equal ["lib/cart.rb"], Dir.chdir(@project.dir) { MutationLanes.changed_since(@first) }
  end

  def test_should_have_nothing_to_compare_with_for_a_commit_git_does_not_know
    assert_nil(Dir.chdir(@project.dir) { MutationLanes.changed_since("0" * 40) })
  end
end
