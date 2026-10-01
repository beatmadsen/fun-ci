# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/installed_hooks"
require "fun_ci/setup/hook_script"
require "tmpdir"

# What `fun-ci check` warns of in the hooks git runs: one that doesn't run
# fun-ci tests no commit, or lets a push through without a verdict, while
# the project's own setup is fine (AT-1.13). Here a hooks directory in a
# temp dir.
class TestInstalledHooks < Minitest::Test
  OTHER_TOOL = "#!/bin/sh\n# husky managed hook\nnpx lint-staged\n"

  def setup
    @hooks_dir = File.join(Dir.mktmpdir("installed-hooks"), "hooks")
    FileUtils.mkdir_p(@hooks_dir)
  end

  def teardown = FileUtils.rm_rf(File.dirname(@hooks_dir))

  def test_should_warn_that_no_commit_is_tested_without_a_post_commit_hook
    hook("pre-push", FunCi::Setup::HookScript.for("pre-push"))

    assert_equal ["No commit is tested: the post-commit hook doesn't run fun-ci. Run `fun-ci install-hooks`"],
                 warnings
  end

  def test_should_warn_that_a_push_waits_for_no_verdict_when_another_tool_s_pre_push_does_not_run_fun_ci
    hook("post-commit", FunCi::Setup::HookScript.for("post-commit"))
    hook("pre-push", OTHER_TOOL)

    assert_equal ["No push waits for a verdict: the pre-push hook is another tool's and doesn't run fun-ci. " \
                  "Have it run `fun-ci wait <commit> --need fast` for each commit pushed"], warnings
  end

  def test_should_warn_of_nothing_when_both_hooks_run_fun_ci
    hook("post-commit", "#!/bin/sh\nnpx lint-staged\nfun-ci trigger --background \"$(git rev-parse HEAD)\" main\n")
    hook("pre-push", FunCi::Setup::HookScript.for("pre-push"))

    assert_empty warnings
  end

  # Outside a git repository there are no hooks to look at.
  def test_should_warn_of_nothing_without_a_hooks_directory
    assert_empty FunCi::Setup::InstalledHooks.new(nil).warnings
  end

  private

  def hook(type, script) = File.write(File.join(@hooks_dir, type), script)
  def warnings = FunCi::Setup::InstalledHooks.new(@hooks_dir).warnings
end
