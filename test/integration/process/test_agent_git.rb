# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/git_project"
require "fun_ci/agent/git"

# What agent commands ask the project's git: which commit a revision names,
# its subject, and the project's top directory.
class TestAgentGit < Minitest::Test
  def setup
    @project = GitProject.create
    @sha = @project.commit_empty("Add retry to fetch")
    @git = FunCi::Agent::Git.new(@project.dir)
  end

  def teardown = @project.remove

  # Trigger names it, as it does for the hooks, which pass the same "".
  def test_should_name_no_branch_when_head_is_detached
    @project.git("checkout", "--detach")

    assert_equal "", @git.branch
  end

  def test_should_resolve_head_to_its_full_sha
    assert_equal @sha, @git.resolve("HEAD")
  end

  def test_should_resolve_a_short_sha
    assert_equal @sha, @git.resolve(@sha[0, 7])
  end

  def test_should_resolve_nothing_git_does_not_know
    assert_nil @git.resolve("nosuch")
  end

  def test_should_read_a_commit_s_subject
    assert_equal "Add retry to fetch", @git.subject(@sha)
  end

  def test_should_find_the_top_directory_from_a_subdirectory
    Dir.mkdir(File.join(@project.dir, "sub"))

    assert_equal File.realpath(@project.dir), FunCi::Agent::Git.new(File.join(@project.dir, "sub")).toplevel
  end
end
