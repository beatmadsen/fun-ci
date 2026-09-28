# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/git_project"
require "fun_ci/setup/git_hooks"

# Where git runs a project's hooks from, which is where fun-ci installs them.
class TestGitHooks < Minitest::Test
  def setup = @project = GitProject.create
  def teardown = @project.remove

  def test_should_find_the_hooks_in_the_git_directory_of_a_plain_repository
    assert_equal File.join(@project.common_dir, "hooks"), hooks_dir(@project.dir)
  end

  def test_should_find_the_hooks_where_core_hooks_path_points
    @project.git("config", "core.hooksPath", ".githooks")

    assert_equal File.join(File.realpath(@project.dir), ".githooks"), hooks_dir(@project.dir)
  end

  # There .git is a file naming the repository's own git directory.
  def test_should_find_the_repository_s_hooks_from_a_linked_worktree
    @project.commit_empty("First")
    worktree = File.join(@project.dir, "wt")
    @project.git("worktree", "add", "-q", worktree)

    assert_equal File.join(@project.common_dir, "hooks"), hooks_dir(worktree)
  end

  def test_should_find_none_outside_a_repository
    Dir.mktmpdir { |dir| assert_nil FunCi::Setup::GitHooks.dir(dir) }
  end

  private

  # Real paths, as macOS reaches temp dirs through a symlink; the hooks
  # directory itself may not exist yet.
  def hooks_dir(dir)
    FunCi::Setup::GitHooks.dir(dir).then { |path| File.join(File.realpath(File.dirname(path)), File.basename(path)) }
  end
end
