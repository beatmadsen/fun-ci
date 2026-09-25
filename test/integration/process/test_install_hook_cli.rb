# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/cli_project"
require "fun_ci/setup/hook_writer"

# The one check HookWriter's own tests can't make with a bare .git/: a hook
# lands where git itself will run it, in a repository `git init` made.
class TestInstallHookCli < Minitest::Test
  include CliProject

  def test_should_install_the_hook_where_git_runs_it
    git_init
    FunCi::Setup::HookWriter.run(project_root: @dir, hook_type: "pre-push", stdout: @stdout)
    hooks_dir = Open3.capture2("git", "rev-parse", "--git-path", "hooks", chdir: @dir).first.strip

    assert File.executable?(File.join(@dir, hooks_dir, "pre-push"))
  end
end
