# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/cli_project"
require "fun_ci/setup/commands"

# What HookWriter's own tests can't check with a directory they name: a hook
# lands where git itself will run it, in a repository `git init` made, and
# where core.hooksPath sends git, as husky and the like set it; and that
# `fun-ci check` reads them there.
class TestInstallHookCli < Minitest::Test
  include CliProject

  def test_should_install_the_hook_where_git_runs_it
    git_init
    install_pre_push

    assert File.executable?(File.join(@dir, git_hooks_dir, "pre-push"))
  end

  def test_should_install_the_hook_where_core_hooks_path_points
    git_init
    Open3.capture2("git", "config", "core.hooksPath", ".githooks", chdir: @dir)
    install_pre_push

    assert File.executable?(File.join(@dir, ".githooks", "pre-push"))
  end

  # `fun-ci check` looks at the hooks where git runs them from.
  def test_should_have_check_warn_that_no_commit_is_tested_when_git_runs_no_fun_ci_hook
    git_init
    FunCi::Setup::Commands.new(@dir, @stdout).check([])

    assert_includes @stdout.string, "Warning: No commit is tested: the post-commit hook doesn't run fun-ci."
  end

  private

  def install_pre_push = FunCi::Setup::Commands.new(@dir, @stdout).install_hooks(["pre-push"])
  def git_hooks_dir = Open3.capture2("git", "rev-parse", "--git-path", "hooks", chdir: @dir).first.strip
end
