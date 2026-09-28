# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/cli_project"
require "fun_ci/setup/commands"

# What HookWriter's own tests can't check with a directory they name: a hook
# lands where git itself will run it, in a repository `git init` made, and
# where core.hooksPath sends git, as husky and the like set it.
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

  private

  def install_pre_push = FunCi::Setup::Commands.new(@dir, @stdout).install_hooks(["pre-push"])
  def git_hooks_dir = Open3.capture2("git", "rev-parse", "--git-path", "hooks", chdir: @dir).first.strip
end
